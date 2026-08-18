-- Cart Ride Script

local Window, Esp = ... -- Get APIs via VarArgs

local Player = game:GetService("Players").LocalPlayer

local Tab = Window:TypeTab("HD Admin Game") -- Spawn a Tab for the Game Type

local CatTab = Tab:NoCategory() -- Some scripts may not need Categories, so, for this, we just do "NoCategory"

local JailCat = Esp:Category("JailCells")
local highlights = {}

local toggle = Tab:AddLoopingToggle("Show Jail Owners", function()
	-- Clean up existing first
	for _, h in pairs(highlights) do
		if h.Destroy then h:Destroy() end
	end
	highlights = {}

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
	for _, h in pairs(highlights) do
		if h.Destroy then h:Destroy() end
	end
	highlights = {}
end)

Tab:Cleanup(function()
	for _, h in pairs(highlights) do
		if h.Destroy then h:Destroy() end
	end
	highlights = {}
end)
