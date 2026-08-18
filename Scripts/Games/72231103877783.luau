-- Build - Creative AutoBuilder Script
-- Ported from Rayfield to ChipLib

local Window, Esp = ...

-- Services
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer

-- Game references
local blocksize = 3
local breakRemote = game.ReplicatedStorage.GameRemotes.BreakBlock
local placeRemote = game.ReplicatedStorage.GameRemotes.PlaceBlock
local changeSlot = game.ReplicatedStorage.GameRemotes.ChangeSlot
local cworld = require(game.Players.LocalPlayer.PlayerScripts.MainLocalScript.CWorld)
local ids = require(game.ReplicatedStorage.AssetsMod.IDs)
local FontAssetsSuccess, FontAssetsResult = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/ChipLag/autoplace/main/fontAssets.lua"))()
end)

local FontAssets
if not FontAssetsSuccess then
	FontAssets = { getPattern = function() return "00000000000000000000000010000" end }
else
	FontAssets = FontAssetsResult
end

-- State
local breakRunning = false
local placeRunning = false
local placeBlockId = nil
local placeItemName = ""
local placeSlot = 0
local origCF = nil
local origPos = nil
local breakCount = 0
local placeCount = 0
local placeOverrideMode = false
local freecamSpeed = 30
local isMobile = uis.TouchEnabled

-- Freecam state
local fcPart = nil
local fcYaw = 0
local fcPitch = 0
local fcRenderConn, fcLockConn, fcInputBeganConn, fcInputChangedConn, fcInputEndedConn
local lockedCF = nil
local keysDown = {}
local touchMoveStart, touchLastPos = nil, nil

-- Area state
local areaCorner1, areaCorner2 = nil, nil
local areaMarker1, areaMarker2 = nil, nil
local areaHighlight1, areaHighlight2 = nil, nil
local useAreaSelection = false

-- Jail state
local jailEnabled = false
local jailConn = nil

-- Structures
local structures = {}

-- ESP
local EspCat = Esp:Category("BuildCreative")
local SelectionA = EspCat:CreateBox({
	ShowText = "Position 1",
	BorderColor = nil,
	FillColor = Color3.new(1, 0, 0),
	Transparency = 0.5,
	Size = Vector3.new(1,1,1)
})
local SelectionB = EspCat:CreateBox({
	ShowText = "Position 2",
	BorderColor = nil,
	FillColor = Color3.new(0, 1, 0),
	Transparency = 0.5,
	Size = Vector3.new(1,1,1)
})
EspCat:SetVisible(false)

-- ============================================================
-- Core Functions
-- ============================================================

local function getCam() return workspace.CurrentCamera end

local function getBlockCoords(worldPos)
	return math.floor(worldPos.X / blocksize + 0.5),
	       math.floor(worldPos.Y / blocksize + 0.5),
	       math.floor(worldPos.Z / blocksize + 0.5)
end

local function getLookRayTarget()
	local cam = getCam()
	if not cam then return Vector3.new(0, 0, 0) end
	local origin = cam.CFrame.Position
	local direction = cam.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local char = localPlayer.Character
	if char then params.FilterDescendantsInstances = {char} end
	local result = workspace:Raycast(origin, direction * 1000, params)
	if result then return result.Position end
	local char = localPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		return char.HumanoidRootPart.Position
	end
	return origin
end

local function updatePlaceInfo()
	local char = localPlayer.Character
	if not char then return false end
	local inv = char:FindFirstChild("Inventory")
	if not inv then return false end
	local slot = inv:FindFirstChild("Slot" .. placeSlot)
	if not slot then return false end
	local data = game:GetService("HttpService"):JSONDecode(slot.Value)
	placeItemName = data.name
	if data.count > 0 and data.name ~= "" then
		local itemDef = ids.ByName.Items[data.name]
		if itemDef then
			local blockName = itemDef.block or data.name
			local blockDef = ids.ByName.Blocks[blockName]
			placeBlockId = blockDef and blockDef.id
			return true
		end
	end
	placeBlockId = nil
	return false
end

local function getSlotWithBlockId(blockId)
	local character = localPlayer.Character
	if not character then return nil end
	local inventory = character:FindFirstChild("Inventory")
	if not inventory then return nil end
	for i = 0, 8 do
		local slot = inventory:FindFirstChild("Slot" .. i)
		if slot then
			local ok, data = pcall(function()
				return game:GetService("HttpService"):JSONDecode(slot.Value)
			end)
			if ok and data and data.name ~= "" then
				local itemDef = ids.ByName.Items[data.name]
				if itemDef then
					local blockName = itemDef.block or data.name
					local blockDef = ids.ByName.Blocks[blockName]
					if blockDef and blockDef.id == blockId then return i end
				end
			end
		end
	end
	return nil
end

local function findAdjacentBlock(x, y, z)
	local neighbors = {
		{dx=0,dy=-1,dz=0}, {dx=0,dy=1,dz=0},
		{dx=-1,dy=0,dz=0}, {dx=1,dy=0,dz=0},
		{dx=0,dy=0,dz=-1}, {dx=0,dy=0,dz=1},
	}
	local dirMap = {[1]=5,[2]=1,[3]=2,[4]=3,[5]=4,[6]=0}
	for i, n in ipairs(neighbors) do
		local block = cworld.getBlock(x+n.dx, y+n.dy, z+n.dz)
		if block and block.id then
			return x+n.dx, y+n.dy, z+n.dz, dirMap[i]
		end
	end
	return nil, nil, nil, nil
end

local function saveState()
	local char = localPlayer.Character
	if char then
		origCF = getCam().CFrame
		origPos = char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.CFrame
	end
end

local function restoreState()
	pcall(function()
		if fcLockConn then fcLockConn:Disconnect(); fcLockConn = nil end
		lockedCF = nil
		if origCF then getCam().CFrame = origCF; origCF = nil end
		if origPos then
			local char = localPlayer.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				char.HumanoidRootPart.CFrame = origPos
			end
			origPos = nil
		end
		getCam().CameraType = Enum.CameraType.Custom
	end)
end

local function startFreecam()
	if fcPart then return end
	local pos = getCam().CFrame.Position
	local look = getCam().CFrame.LookVector

	fcPart = Instance.new("Part")
	fcPart.Anchored = true; fcPart.CanCollide = false; fcPart.Transparency = 1
	fcPart.Size = Vector3.new(1,1,1); fcPart.Parent = workspace
	fcPart.CFrame = CFrame.lookAt(pos, pos + look)
	fcPitch, fcYaw = fcPart.CFrame:ToOrientation()

	getCam().CameraType = Enum.CameraType.Scriptable
	getCam().CFrame = fcPart.CFrame
	uis.MouseBehavior = Enum.MouseBehavior.LockCenter
	uis.MouseIconEnabled = false

	local char = localPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		lockedCF = char.HumanoidRootPart.CFrame
	end

	fcInputBeganConn = uis.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.Touch then
			if input.Position.X < 300 then
				touchMoveStart = input.Position; touchLastPos = input.Position
			end
		else keysDown[input.KeyCode] = true end
	end)
	fcInputChangedConn = uis.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if input.Position.X < 300 then touchLastPos = input.Position end
		end
	end)
	fcInputEndedConn = uis.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchMoveStart = nil; touchLastPos = nil
		else keysDown[input.KeyCode] = false end
	end)

	fcRenderConn = rs.RenderStepped:Connect(function(dt)
		if not fcPart then return end
		getCam().CameraType = Enum.CameraType.Scriptable
		local delta = uis:GetMouseDelta()
		fcYaw = fcYaw - delta.X * 0.008
		fcPitch = math.clamp(fcPitch - delta.Y * 0.008, -math.pi/2.2, math.pi/2.2)
		local orientCf = CFrame.fromOrientation(0, fcYaw, 0)
		local fwd, right, up = orientCf.LookVector, orientCf.RightVector, Vector3.new(0,1,0)
		local moveDir = Vector3.new(0,0,0)
		if keysDown[Enum.KeyCode.W] then moveDir = moveDir + fwd end
		if keysDown[Enum.KeyCode.S] then moveDir = moveDir - fwd end
		if keysDown[Enum.KeyCode.A] then moveDir = moveDir - right end
		if keysDown[Enum.KeyCode.D] then moveDir = moveDir + right end
		if keysDown[Enum.KeyCode.Space] then moveDir = moveDir + up end
		if keysDown[Enum.KeyCode.LeftShift] then moveDir = moveDir - up end
		if keysDown[Enum.KeyCode.Up] then moveDir = moveDir + fwd end
		if keysDown[Enum.KeyCode.Down] then moveDir = moveDir - fwd end
		if keysDown[Enum.KeyCode.Left] then moveDir = moveDir - right end
		if keysDown[Enum.KeyCode.Right] then moveDir = moveDir + right end
		if isMobile and touchMoveStart and touchLastPos then
			local diff = touchLastPos - touchMoveStart
			moveDir = moveDir + (orientCf * CFrame.new(Vector3.new(-diff.X*0.3, 0, -diff.Y*0.3))).Position
			touchMoveStart = touchLastPos
		end
		if moveDir.Magnitude > 0 then
			fcPart.CFrame = fcPart.CFrame + moveDir.Unit * freecamSpeed * dt
		end
		fcPart.CFrame = CFrame.new(fcPart.Position) * CFrame.fromOrientation(fcPitch, fcYaw, 0)
		getCam().CFrame = fcPart.CFrame
	end)

	fcLockConn = rs.Heartbeat:Connect(function()
		if lockedCF then
			local char = localPlayer.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				char.HumanoidRootPart.CFrame = lockedCF
			end
		end
	end)
end

local function stopFreecam()
	if fcRenderConn then fcRenderConn:Disconnect(); fcRenderConn = nil end
	if fcInputBeganConn then fcInputBeganConn:Disconnect(); fcInputBeganConn = nil end
	if fcInputEndedConn then fcInputEndedConn:Disconnect(); fcInputEndedConn = nil end
	if fcInputChangedConn then fcInputChangedConn:Disconnect(); fcInputChangedConn = nil end
	if fcPart then fcPart:Destroy(); fcPart = nil end
	uis.MouseBehavior = Enum.MouseBehavior.Default
	uis.MouseIconEnabled = true
	keysDown = {}; touchMoveStart = nil; touchLastPos = nil
end

local function placeBlockAt(x, y, z, override, blockId, slot)
	local useBlockId = blockId or placeBlockId
	local useSlot = slot or placeSlot
	if not useBlockId then
		if not updatePlaceInfo() then return false end
		useBlockId = placeBlockId; useSlot = placeSlot
	end
	local blockData, chunk = cworld.getBlock(x, y, z)
	if not chunk then return false end
	if blockData and blockData.id then
		if not override then return false end
		if blockData.id == useBlockId then return false end
		local target = Vector3.new(x*blocksize, y*blocksize, z*blocksize)
		getCam().CFrame = CFrame.lookAt(target + Vector3.new(0,5,8), target)
		breakRemote:FireServer(x, y, z, nil)
	end
	local adjX, adjY, adjZ, dir = findAdjacentBlock(x, y, z)
	if not adjX then return false end
	local adjWorld = Vector3.new(adjX*blocksize, adjY*blocksize, adjZ*blocksize)
	getCam().CFrame = CFrame.lookAt(adjWorld + Vector3.new(0,5,0.001), adjWorld)
	local pred = cworld.placeBlock(x, y, z, chunk, dir, useBlockId)
	if not pred then return false end
	task.spawn(function()
		placeRemote:InvokeServer(x, y, z, useSlot, dir)
	end)
	return true
end

local function clearAreaHighlights()
	if areaHighlight1 then areaHighlight1:Destroy(); areaHighlight1 = nil end
	if areaHighlight2 then areaHighlight2:Destroy(); areaHighlight2 = nil end
	if areaMarker1 then areaMarker1:Destroy(); areaMarker1 = nil end
	if areaMarker2 then areaMarker2:Destroy(); areaMarker2 = nil end
	areaCorner1 = nil; areaCorner2 = nil
end

local function makeAreaHighlight(part, which)
	local hl = Instance.new("Highlight")
	hl.FillColor = which == 1 and Color3.new(1,0,0) or Color3.new(0,1,0)
	hl.OutlineColor = which == 1 and Color3.new(0.8,0,0) or Color3.new(0,0.8,0)
	hl.FillTransparency = 0; hl.OutlineTransparency = 0
	hl.Adornee = part; hl.Parent = part
	return hl
end

local function setAreaPoint(which)
	local pos = getLookRayTarget()
	local bx, by, bz = getBlockCoords(pos)
	local blockPos = Vector3.new(bx*blocksize, by*blocksize, bz*blocksize)
	local function createMarker()
		local p = Instance.new("Part")
		p.Anchored = true; p.CanCollide = false
		p.Size = Vector3.new(blocksize-0.0001, blocksize-0.0001, blocksize-0.0001)
		p.CFrame = CFrame.new(blockPos); p.Transparency = 0
		p.Color = which == 1 and Color3.new(1,0,0) or Color3.new(0,1,0)
		p.Material = Enum.Material.Neon; p.Parent = workspace
		return p
	end
	if which == 1 then
		if areaMarker1 then areaMarker1:Destroy() end
		if areaHighlight1 then areaHighlight1:Destroy() end
		areaMarker1 = createMarker()
		areaCorner1 = {bx=bx, by=by, bz=bz}
		areaHighlight1 = makeAreaHighlight(areaMarker1, 1)
		SelectionA:SetPosition(blockPos)
	else
		if areaMarker2 then areaMarker2:Destroy() end
		if areaHighlight2 then areaHighlight2:Destroy() end
		areaMarker2 = createMarker()
		areaCorner2 = {bx=bx, by=by, bz=bz}
		areaHighlight2 = makeAreaHighlight(areaMarker2, 2)
		SelectionB:SetPosition(blockPos)
	end
end

-- Structures
local function getStructureBounds()
	if not areaCorner1 or not areaCorner2 then return nil end
	return {
		minX = math.min(areaCorner1.bx, areaCorner2.bx), maxX = math.max(areaCorner1.bx, areaCorner2.bx),
		minY = math.min(areaCorner1.by, areaCorner2.by), maxY = math.max(areaCorner1.by, areaCorner2.by),
		minZ = math.min(areaCorner1.bz, areaCorner2.bz), maxZ = math.max(areaCorner1.bz, areaCorner2.bz),
		width = math.abs(areaCorner1.bx - areaCorner2.bx) + 1,
		height = math.abs(areaCorner1.by - areaCorner2.by) + 1,
		depth = math.abs(areaCorner1.bz - areaCorner2.bz) + 1,
	}
end

local function saveStructure(name)
	if not name or name == "" then return false, "Name required" end
	if structures[name] then return false, "Already exists" end
	local b = getStructureBounds()
	if not b then return false, "Set both points first" end
	local blocks = {}
	for x = b.minX, b.maxX do
		for y = b.minY, b.maxY do
			for z = b.minZ, b.maxZ do
				local bd = cworld.getBlock(x, y, z)
				if bd and bd.id then
					table.insert(blocks, {x=x-b.minX, y=y-b.minY, z=z-b.minZ, id=bd.id})
				end
			end
		end
	end
	structures[name] = {blocks=blocks, width=b.width, height=b.height, depth=b.depth}
	return true, "Saved"
end

local function loadStructureFromPlayerPos(name, placeMode, rotation)
	rotation = rotation or 0
	local structure = structures[name]
	if not structure then return false, "Not found" end
	local char = localPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return false, "No character" end
	local oPos = char.HumanoidRootPart.Position
	local oX = math.floor(oPos.X / blocksize + 0.5)
	local oY = math.floor(oPos.Y / blocksize + 0.5) - 1
	local oZ = math.floor(oPos.Z / blocksize + 0.5)
	local w, d = structure.width, structure.depth
	local placed = 0
	for _, block in ipairs(structure.blocks) do
		local rx, rz
		if rotation == 0 then rx, rz = block.x, block.z
		elseif rotation == 1 then rx, rz = block.z, w-1-block.x
		elseif rotation == 2 then rx, rz = w-1-block.x, d-1-block.z
		elseif rotation == 3 then rx, rz = d-1-block.z, block.x
		end
		local wX, wY, wZ = oX+rx, oY+block.y, oZ+rz
		local bd = cworld.getBlock(wX, wY, wZ)
		local canPlace = placeMode and true or not (bd and bd.id)
		if placeMode and bd and bd.id == block.id then canPlace = false end
		if canPlace then
			local slot = getSlotWithBlockId(block.id)
			if placeBlockAt(wX, wY, wZ, placeMode, block.id, slot) then
				placed = placed + 1
			end
		end
	end
	return true, string.format("Placed %d blocks", placed)
end

local function deleteStructure(name)
	if not structures[name] then return false, "Not found" end
	structures[name] = nil; return true, "Deleted"
end

local function getStructureList()
	local list = {}
	for name in pairs(structures) do table.insert(list, name) end
	table.sort(list); return list
end

local function getCurrentBlockId()
	local char = localPlayer.Character
	if not char then return nil end
	local inv = char:FindFirstChild("Inventory")
	if not inv then return nil end
	local slot = inv:FindFirstChild("Slot" .. placeSlot)
	if not slot then return nil end
	local data = game:GetService("HttpService"):JSONDecode(slot.Value)
	if data.count <= 0 or data.name == "" then return nil end
	local itemDef = ids.ByName.Items[data.name]
	if not itemDef then return nil end
	local blockName = itemDef.block or data.name
	local blockDef = ids.ByName.Blocks[blockName]
	return blockDef and blockDef.id
end

local function startJail(targetList)
	if jailConn then return end
	jailConn = rs.RenderStepped:Connect(function()
		if not jailEnabled then if jailConn then jailConn:Disconnect(); jailConn = nil end; return end
		local blockId = getCurrentBlockId()
		if not blockId then return end
		for _, tp in ipairs(targetList) do
			local char = tp.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local root = char.HumanoidRootPart
				local oX = math.floor(root.Position.X / blocksize + 0.5)
				local oY = math.floor(root.Position.Y / blocksize + 0.5) - 1
				local oZ = math.floor(root.Position.Z / blocksize + 0.5)
				for y = -2, 3 do
					for x = -2, 2 do
						for z = -2, 2 do
							local isHollow = y < 2 and math.abs(x) <= 1 and math.abs(z) <= 1
							if not isHollow then
								local bd = cworld.getBlock(oX+x, oY+y, oZ+z)
								if not bd or not bd.id or bd.id ~= blockId then
									local slot = getSlotWithBlockId(blockId)
									saveState(); startFreecam()
									placeBlockAt(oX+x, oY+y, oZ+z, true, blockId, slot)
									stopFreecam(); restoreState()
								end
							end
						end
					end
				end
			end
		end
	end)
end

local function stopJail()
	if jailConn then jailConn:Disconnect(); jailConn = nil end
end

-- ============================================================
-- UI
-- ============================================================

local Gs = Window:GameScript("Build - Creative")

-- Area
local AreaCat = Gs:AddCategory("Area")

AreaCat:AddToggle("Use Area Selection", false, function(value)
	useAreaSelection = value
	EspCat:SetVisible(value)
end)

AreaCat:AddButton("Set Point 1", function()
	setAreaPoint(1)
end)

AreaCat:AddButton("Set Point 2", function()
	setAreaPoint(2)
end)

AreaCat:AddButton("Clear Area", function()
	clearAreaHighlights()
	EspCat:SetVisible(false)
end)

-- Settings
local SettingsCat = Gs:AddCategory("Settings")

SettingsCat:AddSlider("Freecam Speed", 5, 100, freecamSpeed)

-- Break
local BreakCat = Gs:AddCategory("Break")

local breakStatusLabel = BreakCat:AddLabel("Status: Idle")
local breakCountLabel = BreakCat:AddLabel("Broken: 0")
BreakCat:AddSlider("Break Radius", 2, 20, 5)

BreakCat:AddButton("Start Break", function()
	if breakRunning or placeRunning then return end
	breakRunning = true
	breakCount = 0
	breakStatusLabel:SetText("Status: Breaking...")
	breakCountLabel:SetText("Broken: 0")
	saveState()
	startFreecam()

	task.spawn(function()
		local ok, err = pcall(function()
			local char = localPlayer.Character
			if not char or not char:FindFirstChild("HumanoidRootPart") then
				breakRunning = false; breakStatusLabel:SetText("Status: No Character"); return
			end
			local bx, by, bz = getBlockCoords(char.HumanoidRootPart.Position)
			local scanCount, maxScans, idle = 0, 100, 0
			while breakRunning do
				scanCount = scanCount + 1
				if scanCount > maxScans then breakStatusLabel:SetText("Status: Max scans"); break end
				local r = 5 -- default; could read from slider
				local sX, eX = bx-r, bx+r
				local sY, eY = by-r, by+r
				local sZ, eZ = bz-r, bz+r
				if useAreaSelection and areaCorner1 and areaCorner2 then
					sX = math.min(areaCorner1.bx, areaCorner2.bx); eX = math.max(areaCorner1.bx, areaCorner2.bx)
					sY = math.min(areaCorner1.by, areaCorner2.by); eY = math.max(areaCorner1.by, areaCorner2.by)
					sZ = math.min(areaCorner1.bz, areaCorner2.bz); eZ = math.max(areaCorner1.bz, areaCorner2.bz)
				end
				local anyBroken = false
				for x = sX, eX do
					for y = sY, eY do
						for z = sZ, eZ do
							if not breakRunning then break end
							local block = cworld.getBlock(x, y, z)
							if block and block.id and block.quad ~= false then
								local target = Vector3.new(x*blocksize, y*blocksize, z*blocksize)
								lockedCF = CFrame.new(target + Vector3.new(0,5,0))
								getCam().CFrame = CFrame.lookAt(target + Vector3.new(0,5,8), target)
								breakRemote:FireServer(x, y, z, nil)
								anyBroken = true
								breakCount = breakCount + 1
								breakCountLabel:SetText("Broken: " .. breakCount)
							end
						end
						if not breakRunning then break end
					end
					if not breakRunning then break end
				end
				if not anyBroken then
					idle = idle + 1
					if idle >= 2 then
						breakStatusLabel:SetText("Status: Done (" .. breakCount .. " broken)")
						breakRunning = false; break
					end
					task.wait(0.5)
				else idle = 0 end
			end
		end)
		if not ok then warn("Break error:", err) end
		breakRunning = false
		stopFreecam(); restoreState()
	end)
end)

BreakCat:AddButton("Stop Break", function()
	breakRunning = false
	breakStatusLabel:SetText("Status: Stopped")
end)

-- Place
local PlaceCat = Gs:AddCategory("Place")

local placeStatusLabel = PlaceCat:AddLabel("Status: Idle")
local placeCountLabel = PlaceCat:AddLabel("Placed: 0")
local placeInfoLabel = PlaceCat:AddLabel("Item: none")
PlaceCat:AddSlider("Place Radius", 2, 20, 5)

PlaceCat:AddToggle("Override Mode", false, function(value)
	placeOverrideMode = value
end)

PlaceCat:AddButton("Select Slot", function()
	placeSlot = 0 -- could read from slider
	changeSlot:InvokeServer(placeSlot)
	task.wait(0.1)
	if updatePlaceInfo() then
		placeInfoLabel:SetText("Item: " .. placeItemName .. " (Slot " .. placeSlot .. ")")
	else
		placeInfoLabel:SetText("Item: none (Slot " .. placeSlot .. ")")
	end
end)

PlaceCat:AddButton("Start Place", function()
	if placeRunning or breakRunning then return end
	if not updatePlaceInfo() then
		placeStatusLabel:SetText("Status: No valid block"); return
	end
	placeRunning = true; placeCount = 0
	placeStatusLabel:SetText("Status: Placing...")
	placeCountLabel:SetText("Placed: 0")
	saveState(); startFreecam()
	changeSlot:InvokeServer(placeSlot)

	task.spawn(function()
		local ok, err = pcall(function()
			local char = localPlayer.Character
			if not char or not char:FindFirstChild("HumanoidRootPart") then
				placeRunning = false; placeStatusLabel:SetText("Status: No Character"); return
			end
			local bx, by, bz = getBlockCoords(char.HumanoidRootPart.Position)
			local scanCount, maxScans, idle = 0, 100, 0
			while placeRunning do
				scanCount = scanCount + 1
				if scanCount > maxScans then placeStatusLabel:SetText("Status: Max scans"); break end
				if not updatePlaceInfo() then placeStatusLabel:SetText("Status: No blocks left"); placeRunning = false; break end
				local r = 5
				local sX, eX = bx-r, bx+r
				local sY, eY = by-r, by+r
				local sZ, eZ = bz-r, bz+r
				if useAreaSelection and areaCorner1 and areaCorner2 then
					sX = math.min(areaCorner1.bx, areaCorner2.bx); eX = math.max(areaCorner1.bx, areaCorner2.bx)
					sY = math.min(areaCorner1.by, areaCorner2.by); eY = math.max(areaCorner1.by, areaCorner2.by)
					sZ = math.min(areaCorner1.bz, areaCorner2.bz); eZ = math.max(areaCorner1.bz, areaCorner2.bz)
				end
				local anyPlaced = false
				for x = sX, eX do
					for y = sY, eY do
						for z = sZ, eZ do
							if not placeRunning then break end
							local bd = cworld.getBlock(x, y, z)
							local shouldPlace = not bd or not bd.id
							if placeOverrideMode and bd and bd.id and bd.id ~= placeBlockId then shouldPlace = true end
							if shouldPlace then
								if placeBlockAt(x, y, z, placeOverrideMode, placeBlockId, placeSlot) then
									anyPlaced = true; placeCount = placeCount + 1
									placeCountLabel:SetText("Placed: " .. placeCount)
								end
							end
						end
						if not placeRunning then break end
					end
					if not placeRunning then break end
				end
				if not anyPlaced then
					idle = idle + 1
					if idle >= 2 then
						placeStatusLabel:SetText("Status: Done (" .. placeCount .. " placed)")
						placeRunning = false; break
					end
					task.wait(0.5)
				else idle = 0 end
			end
		end)
		if not ok then warn("Place error:", err) end
		placeRunning = false
		stopFreecam(); restoreState()
	end)
end)

PlaceCat:AddButton("Stop Place", function()
	placeRunning = false
	placeStatusLabel:SetText("Status: Stopped")
end)

-- Structures
local StructCat = Gs:AddCategory("Structures")

StructCat:AddTextBox("Structure Name", "")
StructCat:AddSlider("Rotation", 0, 3, 0)

local structListLabel = StructCat:AddLabel("No structures saved")

StructCat:AddButton("Save Structure", function()
	local name = StructCat:Get("Structure Name").Value
	local ok, msg = saveStructure(name)
	structListLabel:SetText(msg or "Failed")
end)

StructCat:AddButton("Load Structure", function()
	local name = StructCat:Get("Structure Name").Value
	local rot = StructCat:Get("Rotation").Value or 0
	local ok, msg = loadStructureFromPlayerPos(name, false, rot)
	structListLabel:SetText(msg or "Failed")
end)

StructCat:AddButton("Load & Override", function()
	local name = StructCat:Get("Structure Name").Value
	local rot = StructCat:Get("Rotation").Value or 0
	local ok, msg = loadStructureFromPlayerPos(name, true, rot)
	structListLabel:SetText(msg or "Failed")
end)

StructCat:AddButton("Delete Structure", function()
	local name = StructCat:Get("Structure Name").Value
	local ok, msg = deleteStructure(name)
	structListLabel:SetText(msg or "Failed")
end)

StructCat:AddButton("Refresh List", function()
	local list = getStructureList()
	structListLabel:SetText(#list == 0 and "No structures" or "Saved: " .. table.concat(list, ", "))
end)

-- Jail
local JailCat = Gs:AddCategory("Jail")

JailCat:AddTextBox("Player Names", "")

JailCat:AddButton("Start Jail", function()
	if jailEnabled then return end
	jailEnabled = true
	local names = JailCat:Get("Player Names").Value
	local targetList = {}
	if names ~= "" then
		for name in string.gmatch(names, "[^,]+") do
			name = string.match(name, "^%s*(.-)%s*$")
			if name ~= "" then
				for _, p in ipairs(players:GetPlayers()) do
					if string.lower(p.Name) == string.lower(name) or string.lower(p.DisplayName) == string.lower(name) then
						table.insert(targetList, p); break
					end
				end
			end
		end
	end
	if #targetList == 0 then table.insert(targetList, localPlayer) end
	startJail(targetList)
end)

JailCat:AddButton("Stop Jail", function()
	jailEnabled = false
	stopJail()
end)

-- Text Builder
local TextCat = Gs:AddCategory("Text Builder")

TextCat:AddTextBox("Text", "")
local textPlacedBlocks = {}

TextCat:AddButton("Build Text", function()
	local text = TextCat:Get("Text").Value
	if not text or text == "" then Window:Notification(3, "Enter text first"); return end
	local blockId = getCurrentBlockId()
	local slot = getSlotWithBlockId(blockId)
	if not blockId or not slot then Window:Notification(3, "Select a block in hotbar"); return end
	local char = localPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local rootPos = char.HumanoidRootPart.Position
	local startGx = math.floor(rootPos.X / blocksize) - math.floor(#text * 3)
	local startGy = math.floor(rootPos.Y / blocksize)
	local startGz = math.floor(rootPos.Z / blocksize)
	local placed = 0
	for i = 1, #text do
		local c = string.sub(text, i, i)
		local pattern = FontAssets.getPattern(c)
		if pattern then
			for row = 0, 4 do
				for col = 0, 4 do
					if string.sub(pattern, row*5+col+1, row*5+col+1) == "1" then
						local gx = startGx + (i-1)*6 + col
						local gy = startGy + (4-row)
						if placeBlockAt(gx, gy, startGz, false, blockId, slot) then
							table.insert(textPlacedBlocks, {x=gx, y=gy, z=startGz})
							placed = placed + 1
						end
					end
				end
			end
		end
	end
	Window:Notification(3, "Placed " .. placed .. " blocks for '" .. text .. "'")
end)

TextCat:AddButton("Clear Built Text", function()
	if #textPlacedBlocks == 0 then Window:Notification(3, "Nothing to clear"); return end
	local blockId = getCurrentBlockId()
	local cleared = 0
	for _, pos in ipairs(textPlacedBlocks) do
		local bd = cworld.getBlock(pos.x, pos.y, pos.z)
		if bd and bd.id then
			breakRemote:FireServer(pos.x, pos.y, pos.z, nil)
			cleared = cleared + 1
		end
	end
	textPlacedBlocks = {}
	Window:Notification(3, "Broke " .. cleared .. " blocks")
end)

-- Cleanup
Gs:Cleanup(function()
	breakRunning = false; placeRunning = false; jailEnabled = false
	stopFreecam(); restoreState(); stopJail()
	EspCat:SetVisible(false)
end)

Window:Notification(5, "Build - Creative loaded!")
