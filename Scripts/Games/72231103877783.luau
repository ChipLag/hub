-- Build - Creative AutoBuilder Script
-- Ported from Rayfield to ChipLib

local Window, Esp = ...

-- Services
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer

-- Variables
local blocksize = 3
local maxDist = 16.5
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
	warn("Failed to load FontAssets: " .. tostring(FontAssetsResult))
	FontAssets = {
		getPattern = function(char)
			return "00000000000000000000000010000"
		end
	}
else
	FontAssets = FontAssetsResult
end

-- State variables
local breakRunning = false
local placeRunning = false
local radius = 5
local placeSlot = 0
local placeBlockId = nil
local placeItemName = ""
local origCF = nil
local origPos = nil
local breakCount = 0
local placeCount = 0
local idleLimit = 2
local freecamSpeed = 30
local placeOverrideMode = false
local isMobile = uis.TouchEnabled

-- Structures storage
local structures = {}

-- Freecam state
local fcPart = nil
local fcYaw = 0
local fcPitch = 0
local fcRenderConn = nil
local fcLockConn = nil
local fcInputBeganConn = nil
local fcInputChangedConn = nil
local fcInputEndedConn = nil
local lockedCF = nil
local keysDown = {}
local touchMoveStart = nil
local touchLastPos = nil

-- Area selection state
local areaCorner1 = nil
local areaCorner2 = nil
local areaHighlight1 = nil
local areaHighlight2 = nil
local areaMarker1 = nil
local areaMarker2 = nil
local useAreaSelection = false

-- Jail state
local jailEnabled = false
local jailConn = nil
local jailTargetPlayers = ""

-- ESP for area selection
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

-- Core functions
local function getCam()
	return workspace.CurrentCamera
end

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
	if char then
		params.FilterDescendantsInstances = {char}
	end
	local result = workspace:Raycast(origin, direction * 1000, params)
	if result then
		return result.Position
	end
	local char = localPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		return char.HumanoidRootPart.Position
	end
	return origin
end

local function updatePlaceInfo()
	local inv = localPlayer.Character.Inventory
	local slot = inv:FindFirstChild("Slot" .. placeSlot)
	if slot then
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
			local success, data = pcall(function()
				return game:GetService("HttpService"):JSONDecode(slot.Value)
			end)
			if success and data and data.name ~= "" then
				local itemDef = ids.ByName.Items[data.name]
				if itemDef then
					local blockName = itemDef.block or data.name
					local blockDef = ids.ByName.Blocks[blockName]
					if blockDef and blockDef.id == blockId then
						return i
					end
				end
			end
		end
	end
	return nil
end

local function findAdjacentBlock(x, y, z)
	local neighbors = {
		{dx = 0, dy = -1, dz = 0},
		{dx = 0, dy = 1, dz = 0},
		{dx = -1, dy = 0, dz = 0},
		{dx = 1, dy = 0, dz = 0},
		{dx = 0, dy = 0, dz = -1},
		{dx = 0, dy = 0, dz = 1},
	}
	local dirMap = {
		[1] = 5,
		[2] = 1,
		[3] = 2,
		[4] = 3,
		[5] = 4,
		[6] = 0,
	}
	for i, n in ipairs(neighbors) do
		local block, _ = cworld.getBlock(x + n.dx, y + n.dy, z + n.dz)
		if block and block.id then
			return x + n.dx, y + n.dy, z + n.dz, dirMap[i]
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
		if fcLockConn then
			fcLockConn:Disconnect()
			fcLockConn = nil
		end
		lockedCF = nil
		if origCF then
			getCam().CFrame = origCF
			origCF = nil
		end
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
	fcPart.Anchored = true
	fcPart.CanCollide = false
	fcPart.Transparency = 1
	fcPart.Size = Vector3.new(1, 1, 1)
	fcPart.Parent = workspace

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

	fcInputBeganConn = uis.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.Touch then
			local screenPos = input.Position
			if screenPos.X < 300 then
				touchMoveStart = screenPos
				touchLastPos = screenPos
			end
		else
			keysDown[input.KeyCode] = true
		end
	end)

	fcInputChangedConn = uis.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			local screenPos = input.Position
			if screenPos.X < 300 then
				touchLastPos = screenPos
			end
		end
	end)

	fcInputEndedConn = uis.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchMoveStart = nil
			touchLastPos = nil
		else
			keysDown[input.KeyCode] = false
		end
	end)

	fcRenderConn = rs.RenderStepped:Connect(function(dt)
		if not fcPart then return end
		getCam().CameraType = Enum.CameraType.Scriptable

		local delta = uis:GetMouseDelta()
		fcYaw = fcYaw - delta.X * 0.008
		fcPitch = math.clamp(fcPitch - delta.Y * 0.008, -math.pi / 2.2, math.pi / 2.2)

		local orientCf = CFrame.fromOrientation(0, fcYaw, 0)
		local fwd = orientCf.LookVector
		local right = orientCf.RightVector
		local up = Vector3.new(0, 1, 0)

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
			local move = Vector3.new(-diff.X * 0.3, 0, -diff.Y * 0.3)
			local rotatedMove = (orientCf * CFrame.new(move)).Position
			moveDir = moveDir + rotatedMove
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
	keysDown = {}
	touchMoveStart = nil
	touchLastPos = nil
end

local function placeBlockAt(x, y, z, override, blockId, slot)
	local useBlockId = blockId or placeBlockId
	local useSlot = slot or placeSlot
	if not useBlockId then
		if not updatePlaceInfo() then return false end
		useBlockId = placeBlockId
		useSlot = placeSlot
	end

	local blockData, chunk = cworld.getBlock(x, y, z)
	if not chunk then return false end

	if blockData and blockData.id then
		if not override then return false end
		if blockData.id == useBlockId then return false end
		local target = Vector3.new(x * blocksize, y * blocksize, z * blocksize)
		getCam().CFrame = CFrame.lookAt(target + Vector3.new(0, 5, 8), target)
		breakRemote:FireServer(x, y, z, nil)
	end

	local adjX, adjY, adjZ, dir = findAdjacentBlock(x, y, z)
	if not adjX then return false end

	local adjWorld = Vector3.new(adjX * blocksize, adjY * blocksize, adjZ * blocksize)
	getCam().CFrame = CFrame.lookAt(adjWorld + Vector3.new(0, 5, 0.001), adjWorld)

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
	areaCorner1 = nil
	areaCorner2 = nil
end

local function makeAreaHighlight(part, which)
	local hl = Instance.new("Highlight")
	hl.FillColor = which == 1 and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
	hl.OutlineColor = which == 1 and Color3.new(0.8, 0, 0) or Color3.new(0, 0.8, 0)
	hl.FillTransparency = 0
	hl.OutlineTransparency = 0
	hl.Adornee = part
	hl.Parent = part
	return hl
end

local function setAreaPoint(which)
	local pos = getLookRayTarget()
	local bx, by, bz = getBlockCoords(pos)
	local blockPos = Vector3.new(bx * blocksize, by * blocksize, bz * blocksize)

	local function createMarker()
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(blocksize - 0.0001, blocksize - 0.0001, blocksize - 0.0001)
		p.CFrame = CFrame.new(blockPos)
		p.Transparency = 0
		p.Color = which == 1 and Color3.new(1, 0, 0) or Color3.new(0, 1, 0)
		p.Material = Enum.Material.Neon
		p.Parent = workspace
		return p
	end

	if which == 1 then
		if areaMarker1 then areaMarker1:Destroy() end
		if areaHighlight1 then areaHighlight1:Destroy() end
		areaMarker1 = createMarker()
		areaCorner1 = {bx = bx, by = by, bz = bz}
		areaHighlight1 = makeAreaHighlight(areaMarker1, 1)
		SelectionA:SetPosition(Vector3.new(bx * blocksize, by * blocksize, bz * blocksize))
	else
		if areaMarker2 then areaMarker2:Destroy() end
		if areaHighlight2 then areaHighlight2:Destroy() end
		areaMarker2 = createMarker()
		areaCorner2 = {bx = bx, by = by, bz = bz}
		areaHighlight2 = makeAreaHighlight(areaMarker2, 2)
		SelectionB:SetPosition(Vector3.new(bx * blocksize, by * blocksize, bz * blocksize))
	end
end

-- Structure functions
local function getStructureBounds()
	if not areaCorner1 or not areaCorner2 then return nil end
	local minX = math.min(areaCorner1.bx, areaCorner2.bx)
	local maxX = math.max(areaCorner1.bx, areaCorner2.bx)
	local minY = math.min(areaCorner1.by, areaCorner2.by)
	local maxY = math.max(areaCorner1.by, areaCorner2.by)
	local minZ = math.min(areaCorner1.bz, areaCorner2.bz)
	local maxZ = math.max(areaCorner1.bz, areaCorner2.bz)
	return {
		minX = minX, maxX = maxX,
		minY = minY, maxY = maxY,
		minZ = minZ, maxZ = maxZ,
		width = maxX - minX + 1,
		height = maxY - minY + 1,
		depth = maxZ - minZ + 1
	}
end

local function saveStructure(name)
	if not name or name == "" then return false, "Name cannot be empty" end
	if structures[name] then return false, "Structure already exists" end
	local bounds = getStructureBounds()
	if not bounds then return false, "Set both area points first" end
	local blocks = {}
	for x = bounds.minX, bounds.maxX do
		for y = bounds.minY, bounds.maxY do
			for z = bounds.minZ, bounds.maxZ do
				local blockData, _ = cworld.getBlock(x, y, z)
				if blockData and blockData.id then
					table.insert(blocks, {
						x = x - bounds.minX,
						y = y - bounds.minY,
						z = z - bounds.minZ,
						id = blockData.id
					})
				end
			end
		end
	end
	structures[name] = {
		blocks = blocks,
		width = bounds.width,
		height = bounds.height,
		depth = bounds.depth
	}
	return true, "Structure saved"
end

local function loadStructureFromPlayerPos(name, placeMode, rotation)
	rotation = rotation or 0
	local structure = structures[name]
	if not structure then return false, "Structure not found" end
	local char = localPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return false, "No character" end
	local originPos = char.HumanoidRootPart.Position
	local originX = math.floor(originPos.X / blocksize + 0.5)
	local originY = math.floor(originPos.Y / blocksize + 0.5) - 1
	local originZ = math.floor(originPos.Z / blocksize + 0.5)
	local width = structure.width
	local depth = structure.depth
	local placedCount = 0
	for _, block in ipairs(structure.blocks) do
		local x, y, z = block.x, block.y, block.z
		local rx, rz
		if rotation == 0 then rx, rz = x, z
		elseif rotation == 1 then rx, rz = z, width - 1 - x
		elseif rotation == 2 then rx, rz = width - 1 - x, depth - 1 - z
		elseif rotation == 3 then rx, rz = depth - 1 - z, x
		end
		local worldX = originX + rx
		local worldY = originY + y
		local worldZ = originZ + rz
		local blockData, _ = cworld.getBlock(worldX, worldY, worldZ)
		local canPlace = true
		if not placeMode then
			if blockData and blockData.id then canPlace = false end
		else
			if blockData and blockData.id == block.id then canPlace = false end
		end
		if canPlace then
			local slot = getSlotWithBlockId(block.id)
			if placeBlockAt(worldX, worldY, worldZ, placeMode, block.id, slot) then
				placedCount = placedCount + 1
			end
		end
	end
	return true, string.format("Placed %d blocks", placedCount)
end

local function deleteStructure(name)
	if not structures[name] then return false, "Not found" end
	structures[name] = nil
	return true, "Deleted"
end

local function getStructureList()
	local list = {}
	for name, _ in pairs(structures) do table.insert(list, name) end
	table.sort(list)
	return list
end

local function getCurrentBlockId()
	if not placeSlot then return nil end
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

local function startJail(targetPlayersList)
	if jailConn then return end
	jailConn = rs.RenderStepped:Connect(function()
		if not jailEnabled then
			if jailConn then jailConn:Disconnect(); jailConn = nil end
			return
		end
		local blockId = getCurrentBlockId()
		if not blockId then return end
		local totalBlocksPlaced = 0
		for _, targetPlayer in ipairs(targetPlayersList) do
			local char = targetPlayer.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local root = char.HumanoidRootPart
				local originPos = root.Position
				local originX = math.floor(originPos.X / blocksize + 0.5)
				local originY = math.floor(originPos.Y / blocksize + 0.5) - 1
				local originZ = math.floor(originPos.Z / blocksize + 0.5)
				for y = -2, 3 do
					for x = -2, 2 do
						for z = -2, 2 do
							local isHollow = false
							if y < 2 and math.abs(x) <= 1 and math.abs(z) <= 1 then
								isHollow = true
							end
							if not isHollow then
								local blockData, _ = cworld.getBlock(originX + x, originY + y, originZ + z)
								if not blockData or not blockData.id or blockData.id ~= blockId then
									local slot = getSlotWithBlockId(blockId)
									saveState()
									startFreecam()
									if placeBlockAt(originX + x, originY + y, originZ + z, true, blockId, slot) then
										totalBlocksPlaced = totalBlocksPlaced + 1
									end
									stopFreecam()
									restoreState()
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
	useAreaSelection = false
end)

-- Break
local BreakCat = Gs:AddCategory("Break")

BreakCat:AddTextBox("Radius", tostring(radius))

local breakLabel = BreakCat:AddLabel("Status: Idle")
local breakCountLabel = BreakCat:AddLabel("Broken: 0")

local breakToggleButton = BreakCat:AddLoopingToggle("Start Break", function(dt)
	if not breakRunning then return end
	local char = localPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		breakRunning = false
		return
	end
	local bx, by, bz = getBlockCoords(char.HumanoidRootPart.Position)
	local r = tonumber(BreakCat:Get("Radius").Value) or 5
	local scanMinX = bx - r
	local scanMaxX = bx + r
	local scanMinY = by - r
	local scanMaxY = by + r
	local scanMinZ = bz - r
	local scanMaxZ = bz + r

	if useAreaSelection and areaCorner1 and areaCorner2 then
		scanMinX = math.min(areaCorner1.bx, areaCorner2.bx)
		scanMaxX = math.max(areaCorner1.bx, areaCorner2.bx)
		scanMinY = math.min(areaCorner1.by, areaCorner2.by)
		scanMaxY = math.max(areaCorner1.by, areaCorner2.by)
		scanMinZ = math.min(areaCorner1.bz, areaCorner2.bz)
		scanMaxZ = math.max(areaCorner1.bz, areaCorner2.bz)
	end

	local anyBroken = false
	for x = scanMinX, scanMaxX do
		for y = scanMinY, scanMaxY do
			for z = scanMinZ, scanMaxZ do
				if not breakRunning then return end
				local block, _ = cworld.getBlock(x, y, z)
				if block and block.id and block.quad ~= false then
					local target = Vector3.new(x * blocksize, y * blocksize, z * blocksize)
					lockedCF = CFrame.new(target + Vector3.new(0, 5, 0))
					getCam().CFrame = CFrame.lookAt(target + Vector3.new(0, 5, 8), target)
					breakRemote:FireServer(x, y, z, nil)
					anyBroken = true
					breakCount = breakCount + 1
					breakCountLabel:SetText("Broken: " .. breakCount)
					breakCount = breakCount + 1
				end
			end
		end
	end
	if not anyBroken then
		breakRunning = false
		breakToggleButton:SetText("Start Break")
		breakLabel:SetText("Status: Done")
	end
end, function(value)
	if value then
		breakRunning = true
		breakCount = 0
		breakToggleButton:SetText("Stop Break")
		breakLabel:SetText("Status: Breaking...")
		saveState()
		startFreecam()
	else
		breakRunning = false
		breakToggleButton:SetText("Start Break")
		breakLabel:SetText("Status: Stopped")
		stopFreecam()
		restoreState()
	end
end)

BreakCat:AddButton("Stop Break", function()
	breakRunning = false
	breakLabel:SetText("Status: Stopped")
end)

-- Place
local PlaceCat = Gs:AddCategory("Place")

PlaceCat:AddTextBox("Slot", tostring(placeSlot))
PlaceCat:AddTextBox("Radius", tostring(radius))

local placeLabel = PlaceCat:AddLabel("Status: Idle")
local placeCountLabel = PlaceCat:AddLabel("Placed: 0")

local placeToggleButton = PlaceCat:AddLoopingToggle("Start Place", function(dt)
	if not placeRunning then return end
	if not updatePlaceInfo() then
		placeRunning = false
		placeLabel:SetText("Status: No blocks left")
		return
	end
	local char = localPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		placeRunning = false
		return
	end
	local bx, by, bz = getBlockCoords(char.HumanoidRootPart.Position)
	local r = tonumber(PlaceCat:Get("Radius").Value) or 5
	local scanMinX = bx - r
	local scanMaxX = bx + r
	local scanMinY = by - r
	local scanMaxY = by + r
	local scanMinZ = bz - r
	local scanMaxZ = bz + r

	if useAreaSelection and areaCorner1 and areaCorner2 then
		scanMinX = math.min(areaCorner1.bx, areaCorner2.bx)
		scanMaxX = math.max(areaCorner1.bx, areaCorner2.bx)
		scanMinY = math.min(areaCorner1.by, areaCorner2.by)
		scanMaxY = math.max(areaCorner1.by, areaCorner2.by)
		scanMinZ = math.min(areaCorner1.bz, areaCorner2.bz)
		scanMaxZ = math.max(areaCorner1.bz, areaCorner2.bz)
	end

	local anyPlaced = false
	for x = scanMinX, scanMaxX do
		for y = scanMinY, scanMaxY do
			for z = scanMinZ, scanMaxZ do
				if not placeRunning then return end
				local blockData, _ = cworld.getBlock(x, y, z)
				local shouldPlace = false
				if not blockData or not blockData.id then
					shouldPlace = true
				elseif placeOverrideMode and blockData.id ~= placeBlockId then
					shouldPlace = true
				end
				if shouldPlace then
					if placeBlockAt(x, y, z, placeOverrideMode, placeBlockId, placeSlot) then
						anyPlaced = true
						placeCount = placeCount + 1
						placeCountLabel:SetText("Placed: " .. placeCount)
					end
				end
			end
		end
	end
	if not anyPlaced then
		placeRunning = false
		placeToggleButton:SetText("Start Place")
		placeLabel:SetText("Status: Done")
	end
end, function(value)
	if value then
		placeSlot = tonumber(PlaceCat:Get("Slot").Value) or 0
		placeRunning = true
		placeCount = 0
		placeToggleButton:SetText("Stop Place")
		placeLabel:SetText("Status: Placing...")
		saveState()
		startFreecam()
		changeSlot:InvokeServer(placeSlot)
	else
		placeRunning = false
		placeToggleButton:SetText("Start Place")
		placeLabel:SetText("Status: Stopped")
		stopFreecam()
		restoreState()
	end
end)

PlaceCat:AddToggle("Override Mode", false, function(value)
	placeOverrideMode = value
end)

PlaceCat:AddButton("Select Slot", function()
	placeSlot = tonumber(PlaceCat:Get("Slot").Value) or 0
	changeSlot:InvokeServer(placeSlot)
	task.wait(0.1)
	if updatePlaceInfo() then
		placeLabel:SetText("Item: " .. placeItemName)
	end
end)

PlaceCat:AddButton("Stop Place", function()
	placeRunning = false
	placeLabel:SetText("Status: Stopped")
end)

-- Structures
local StructCat = Gs:AddCategory("Structures")

StructCat:AddTextBox("Structure Name", "")
StructCat:AddTextBox("Rotation", "0")

local structListLabel = StructCat:AddLabel("No structures saved")

StructCat:AddButton("Save Structure", function()
	local name = StructCat:Get("Structure Name").Value
	local success, message = saveStructure(name)
	structListLabel:SetText(message or "Failed")
end)

StructCat:AddButton("Load Structure", function()
	local name = StructCat:Get("Structure Name").Value
	local rotation = tonumber(StructCat:Get("Rotation").Value) or 0
	local success, message = loadStructureFromPlayerPos(name, false, rotation)
	structListLabel:SetText(message or "Failed")
end)

StructCat:AddButton("Load & Override", function()
	local name = StructCat:Get("Structure Name").Value
	local rotation = tonumber(StructCat:Get("Rotation").Value) or 0
	local success, message = loadStructureFromPlayerPos(name, true, rotation)
	structListLabel:SetText(message or "Failed")
end)

StructCat:AddButton("Delete Structure", function()
	local name = StructCat:Get("Structure Name").Value
	local success, message = deleteStructure(name)
	structListLabel:SetText(message or "Failed")
end)

StructCat:AddButton("Refresh List", function()
	local list = getStructureList()
	if #list == 0 then
		structListLabel:SetText("No structures saved")
	else
		structListLabel:SetText("Saved: " .. table.concat(list, ", "))
	end
end)

-- Jail
local JailCat = Gs:AddCategory("Jail")

JailCat:AddTextBox("Player Names", "")

local jailToggleButton = JailCat:AddLoopingToggle("Enable Jail", function(dt)
	-- Loop handled by startJail
end, function(value)
	jailEnabled = value
	if value then
		local names = JailCat:Get("Player Names").Value
		local targetList = {}
		if names ~= "" then
			for name in string.gmatch(names, "[^,]+") do
				name = string.match(name, "^%s*(.-)%s*$")
				if name ~= "" then
					for _, p in ipairs(players:GetPlayers()) do
						if string.lower(p.Name) == string.lower(name) or string.lower(p.DisplayName) == string.lower(name) then
							table.insert(targetList, p)
							break
						end
					end
				end
			end
		end
		if #targetList == 0 then
			table.insert(targetList, localPlayer)
		end
		startJail(targetList)
	else
		stopJail()
	end
end)

-- Cleanup
Gs:Cleanup(function()
	stopFreecam()
	restoreState()
	stopJail()
	EspCat:SetVisible(false)
end)

Window:Notification(5, "Build - Creative loaded!")
