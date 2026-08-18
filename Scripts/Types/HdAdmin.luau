-- HD Admin Script

local Window, Esp = ...

local Player = game:GetService("Players").LocalPlayer

local Tab = Window:TypeTab("HD Admin Game")
local CatTab = Tab:NoCategory()

local JailCat = Esp:Category("JailCells")
local highlights = {}
local lastToggle = false

local toggle = CatTab:AddLoopingToggle("Show Jail Owners", function()
	if lastToggle then return end
	lastToggle = true

	for _, v in pairs(game.Workspace:GetChildren()) do
		if v.Name:match("s JailCell$") and v:IsA("BasePart") then
			local h = JailCat:Highlight({
				TargetPart = v,
				ShowText = v.Name,
				BorderColor = Color3.new(1, 0, 0),
				FillColor = Color3.new(1, 0, 0),
				Transparency = 0.3,
			})
			table.insert(highlights, h)
		end
	end
end, function(value)
	lastToggle = false
	for _, h in pairs(highlights) do
		if h.Destroy then h:Destroy() end
	end
	highlights = {}
end)

Tab:Cleanup(function()
	lastToggle = false
	for _, h in pairs(highlights) do
		if h.Destroy then h:Destroy() end
	end
	highlights = {}
end)
