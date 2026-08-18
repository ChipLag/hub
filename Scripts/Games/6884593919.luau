-- Build Creative Script

-- Get APIs
local Window, Esp = ... -- We use VarArgs to pass values through the Loadstring

-- Helper Functions

local function raycast()
	local cam = game.Workspace.CurrentCamera
	local origin = cam.CFrame.Position
	local dir = cam.CFrame.LookVector
	local rc = RaycastParams.new()	
	params.FilterType = Enum.RaycastFilterType.Exclude
	local char = Player.Character
	if char then
		params.FilterDescendantsInstances = {char}
	end
	local result = workspace:Raycast(origin, direction * 10, params)
	if result then
		return result.Position
	end
	-- Return player position instead of camera forward position when no block is hit
	local char = players.LocalPlayer.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		return char.HumanoidRootPart.Position
	end
	return origin  -- Fallback to camera origin if no character
end

local function getBlockCoords(worldPos)
    return math.floor(worldPos.X / blocksize + 0.5),
           math.floor(worldPos.Y / blocksize + 0.5),
           math.floor(worldPos.Z / blocksize + 0.5)
end

-- Code
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Gs = Window:GameScript("Build - Creative (1, 2 or 3)") -- GameScript is like a Tab, but the GUI then knows to set the GameScript info to true

-- ESP
local EspCat = Esp:Category("GsBuildCreative")
local SelectionA = EspCat:CreateBox({
	ShowText = "Position 1", -- Nil to disable text, or just don't set value
	BorderColor = nil, -- Required
	FillColor = Color3.new(255, 0, 0), -- Required
	Transparency = 0.5, -- Optional, defaults to fully Opaque
	Size = Vector3.new(1,1,1) -- Required
})
local SelectionB = EspCat:CreateBox({
	ShowText = "Position 2", -- Nil to disable text, or just don't set value
	BorderColor = nil, -- Required
	FillColor = Color3.new(255, 0, 0), -- Required
	Transparency = 0.5, -- Optional, defaults to fully Opaque
	Size = Vector3.new(1,1,1) -- Required
})
EspCat:SetVisible(false) -- Same state as "Use Selection"


-- UI
local SelectCat = Gs:AddCategory("Selection")

SelectCat:AddToggle("Use Selection", false, function(value)
	EspCat:SetVisible(value)
end) -- second value is default value, you could add a callback, but that is optional.

SelectCat:AddButton("Set Position 1", function()
	SelectionA:SetPosition(getBlockCoords(raycast()))
end)


SelectCat:AddButton("Set Position 2", function()
	SelectionB:SetPosition(getBlockCoords(raycast()))
end)

