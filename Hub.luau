--// Hub.luau
--// ChipLag Hub V2 - Main Orchestrator
--// Repository: https://github.com/ChipLag/hub
print("Hub V2.2.3 loaded")

local repo = "https://raw.githubusercontent.com/ChipLag/hub/refs/heads/main/"

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local PlaceId = game.PlaceId

--// ============================================================
--// Load Libraries
--// ============================================================

local ChipLib = loadstring(game:HttpGet(repo .. "Library/ChipLib.luau", true))()
local ChipEsp = loadstring(game:HttpGet(repo .. "Library/ChipEsp.luau", true))()

local Window = ChipLib.new({ Name = "ChipLag Hub" })
local Esp = ChipEsp.new()

Window._Esp = Esp
Window.Settings = { ExcludeFriends = true }

--// ============================================================
--// Hub State
--// ============================================================

local Hub = {}
Hub._GameScriptLoaded = false
Hub._TypesLoaded = 0
Hub._GsCard = nil
Hub._TypesCard = nil
Hub._Loading = {}

--// ============================================================
--// Per-Game Save/Load of Generic Scripts
--// ============================================================

local function getSavePath()
	return "ChipLag/Generics/" .. tostring(PlaceId) .. ".json"
end

local function loadSavedTypes()
	local ok, result = pcall(function()
		if readfile and isfile then
			local path = getSavePath()
			if isfile(path) then
				local content = readfile(path)
				return HttpService:JSONDecode(content)
			end
		end
	end)
	if ok and type(result) == "table" then
		return result
	end
	return {}
end

local function saveEnabledTypes(types)
	pcall(function()
		if writefile then
			writefile(getSavePath(), HttpService:JSONEncode(types))
		end
	end)
end

local SavedTypes = loadSavedTypes()

local function getSettingsPath()
	return "ChipLag/Settings.json"
end

local function loadSettings()
	local ok, content = pcall(function()
		if readfile and isfile then
			local path = getSettingsPath()
			if isfile(path) then
			return HttpService:JSONDecode(readfile(path))
			end
		end
	end)
	if ok and type(content) == "table" then
		return content
	end
	return {}
end

local function saveSettings(settings)
	pcall(function()
		if writefile then
			writefile(getSettingsPath(), HttpService:JSONEncode(settings))
		end
	end)
end

local SavedSettings = loadSettings()
	Window.Settings.ExcludeFriends = SavedSettings.ExcludeFriends ~= false

--// ============================================================
--// Extend Window with script-specific API
--// ============================================================

function Window:Notification(duration, message)
	Window:Notify(tostring(message), tonumber(duration) or 3)
end

function Window:TypeTab(name)
	local tab = Window:AddTab(name, 30 + Hub._TypesLoaded)
	return tab
end

function Window:GameScript(name)
	local tab = Window:AddTab(name, 20)
	Hub._GameScriptLoaded = true
	if Hub._GsCard then
		Hub._GsCard:SetSubtitle("GameScript: Loaded")
	end
	return tab
end

--// ============================================================
--// Fetch remote scripts
--// ============================================================

local function fetchContent(path)
	local ok, content = pcall(function()
		return game:HttpGet(repo .. path, true)
	end)
	if ok and content then
		return content
	end
	warn("[ChipLag] Failed to fetch: " .. path .. " - " .. tostring(content))
	return nil
end

local function fetchScript(path)
	local content = fetchContent(path)
	if content then
		local fn, err = loadstring(content)
		if fn then return fn() end
		warn("[ChipLag] Failed to compile: " .. path .. " - " .. tostring(err))
	end
	return nil
end

local function loadScript(path, ...)
	local content = fetchContent(path)
	if content then
		local fn, err = loadstring(content)
		if fn then
			return fn(...)
		else
			error("Loadstring failed: " .. tostring(err))
		end
	end
	error("Fetch failed: " .. path)
end

--// ============================================================
--// Home Tab
--// ============================================================

local HomeTab = Window:AddTab("Home", 1)
local HomeCat = HomeTab:AddCategory("Info")

local GameName = "Unknown Game"
pcall(function()
	GameName = MarketplaceService:GetProductInfo(PlaceId).Name
end)

local gameThumb = ""
pcall(function()
	gameThumb = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. PlaceId .. "&width=420&height=420&format=png"
end)

local playerThumb = ""
pcall(function()
	playerThumb = Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)

-- Player Welcome Card (50% height)
do
	local frame = HomeCat:AddFrame(UDim2.new(1, 0, 0.5, -4))
	frame.BackgroundColor3 = Color3.fromRGB(36, 38, 52)
	frame.BackgroundTransparency = 0
	frame.ClipsDescendants = true
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = frame

	if playerThumb ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(0.3, 0, 1, 0)
		img.Position = UDim2.new(0, 0, 0, 0)
		img.BackgroundTransparency = 1
		img.Image = playerThumb
		img.ScaleType = Enum.ScaleType.Crop
		img.Parent = frame
	end

	local textContainer = Instance.new("Frame")
	textContainer.Size = UDim2.new(0.67, 0, 1, 0)
	textContainer.Position = UDim2.new(0.33, 0, 0, 0)
	textContainer.BackgroundTransparency = 1
	textContainer.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = textContainer

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = textContainer

	local welcomeLabel = Instance.new("TextLabel")
	welcomeLabel.Size = UDim2.new(1, 0, 0, 0)
	welcomeLabel.AutomaticSize = Enum.AutomaticSize.Y
	welcomeLabel.BackgroundTransparency = 1
	welcomeLabel.Text = "Hello, " .. Player.DisplayName .. "!"
	welcomeLabel.TextColor3 = Color3.fromRGB(230, 232, 240)
	welcomeLabel.TextSize = 18
	welcomeLabel.Font = Enum.Font.GothamBold
	welcomeLabel.TextXAlignment = Enum.TextXAlignment.Left
	welcomeLabel.TextWrapped = true
	welcomeLabel.Parent = textContainer

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0, 0)
	subLabel.AutomaticSize = Enum.AutomaticSize.Y
	subLabel.BackgroundTransparency = 1
	subLabel.Text = "ChipLag Hub"
	subLabel.TextColor3 = Color3.fromRGB(140, 145, 165)
	subLabel.TextSize = 14
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.TextWrapped = true
	subLabel.Parent = textContainer
end

-- Game Info Card (50% height)
do
	local frame = HomeCat:AddFrame(UDim2.new(1, 0, 0.5, -4))
	frame.BackgroundColor3 = Color3.fromRGB(36, 38, 52)
	frame.BackgroundTransparency = 0
	frame.ClipsDescendants = true
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = frame

	if gameThumb ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(0.3, 0, 1, 0)
		img.Position = UDim2.new(0, 0, 0, 0)
		img.BackgroundTransparency = 1
		img.Image = gameThumb
		img.ScaleType = Enum.ScaleType.Crop
		img.Parent = frame
	end

	local textContainer = Instance.new("Frame")
	textContainer.Size = UDim2.new(0.67, 0, 1, 0)
	textContainer.Position = UDim2.new(0.33, 0, 0, 0)
	textContainer.BackgroundTransparency = 1
	textContainer.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = textContainer

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = textContainer

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 0)
	titleLabel.AutomaticSize = Enum.AutomaticSize.Y
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = GameName
	titleLabel.TextColor3 = Color3.fromRGB(230, 232, 240)
	titleLabel.TextSize = 18
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextWrapped = true
	titleLabel.Parent = textContainer

	local gsLabel2 = Instance.new("TextLabel")
	gsLabel2.Size = UDim2.new(1, 0, 0, 0)
	gsLabel2.AutomaticSize = Enum.AutomaticSize.Y
	gsLabel2.BackgroundTransparency = 1
	gsLabel2.Text = "GameScript: None"
	gsLabel2.TextColor3 = Color3.fromRGB(140, 145, 165)
	gsLabel2.TextSize = 14
	gsLabel2.Font = Enum.Font.Gotham
	gsLabel2.TextXAlignment = Enum.TextXAlignment.Left
	gsLabel2.TextWrapped = true
	gsLabel2.Parent = textContainer

	local typesLabel2 = Instance.new("TextLabel")
	typesLabel2.Size = UDim2.new(1, 0, 0, 0)
	typesLabel2.AutomaticSize = Enum.AutomaticSize.Y
	typesLabel2.BackgroundTransparency = 1
	typesLabel2.Text = "Generic Scripts: 0 loaded"
	typesLabel2.TextColor3 = Color3.fromRGB(140, 145, 165)
	typesLabel2.TextSize = 14
	typesLabel2.Font = Enum.Font.Gotham
	typesLabel2.TextXAlignment = Enum.TextXAlignment.Left
	typesLabel2.TextWrapped = true
	typesLabel2.Parent = textContainer

	Hub._GsCard = { SetSubtitle = function(_, s) gsLabel2.Text = s end }
	Hub._TypesCard = { SetFooter = function(_, f) typesLabel2.Text = f end }
end

--// ============================================================
--// Options Tab
--// ============================================================

do
	local OptionsTab = Window:AddTab("Options", 99)
	local OptionsCat = OptionsTab:AddCategory("Settings")

	OptionsCat:AddToggle("Exclude Friends", Window.Settings.ExcludeFriends == true, function(state)
		Window.Settings.ExcludeFriends = state
		SavedSettings.ExcludeFriends = state
		saveSettings(SavedSettings)
	end)
end

--// ============================================================
--// Generic Scripts Tab
-- ============================================================

local TypesTab = Window:AddTab("Generic scripts", 2)
local TypesCat = TypesTab:AddCategory("Types")

local TypeRegistry = fetchScript("Scripts/Types.luau")
local LoadedTypes = {}

local function enableType(displayName, fileName)
	if LoadedTypes[displayName] or Hub._Loading[displayName] then return end
	Hub._Loading[displayName] = true

	local ok, err = pcall(loadScript, "Scripts/Types/" .. fileName .. ".luau", Window, Esp)
	if not ok then
		warn("[ChipLag] Type load failed (" .. displayName .. "): " .. tostring(err))
		Window:Notify("Failed: " .. displayName .. " - " .. tostring(err), 5)
	else
		LoadedTypes[displayName] = true
		Hub._TypesLoaded = Hub._TypesLoaded + 1
		if Hub._TypesCard then
			Hub._TypesCard:SetFooter("Generic Scripts: " .. Hub._TypesLoaded .. " loaded")
		end
		SavedTypes[displayName] = true
		saveEnabledTypes(SavedTypes)
	end
	Hub._Loading[displayName] = nil
end

local function disableType(displayName)
	if not LoadedTypes[displayName] then return end

	for tabName, tab in pairs(Window._Tabs) do
		if tabName == displayName then
			for id, hb in pairs(Window._Heartbeats) do
				if hb.Tab == tabName then
					if hb.Connection then hb.Connection:Disconnect() end
					Window._Heartbeats[id] = nil
				end
			end
			if tab._CleanupFunc then
				pcall(tab._CleanupFunc)
			end
			Window:RemoveTab(tabName)
			break
		end
	end

	LoadedTypes[displayName] = nil
	Hub._TypesLoaded = Hub._TypesLoaded - 1
	if Hub._TypesCard then
		Hub._TypesCard:SetFooter("Generic Scripts: " .. Hub._TypesLoaded .. " loaded")
	end
	SavedTypes[displayName] = nil
	saveEnabledTypes(SavedTypes)
end

if TypeRegistry then
	for displayName, fileName in pairs(TypeRegistry) do
		TypesCat:AddToggle(displayName, SavedTypes[displayName] == true, function(state)
			if state then
				enableType(displayName, fileName)
			else
				disableType(displayName)
			end
		end)
	end
end

task.defer(function()
	if TypeRegistry then
		for displayName, fileName in pairs(TypeRegistry) do
			if SavedTypes[displayName] then
				enableType(displayName, fileName)
			end
		end
	end
end)

--// ============================================================
--// Misc Tab
--// ============================================================

do
	local MiscTab = Window:AddTab("Misc.", 25)
	local MiscCat = MiscTab:AddCategory("Scripts")

	local MiscRegistry = fetchScript("Scripts/Misc.luau")
	if MiscRegistry then
		for displayName, url in pairs(MiscRegistry) do
			MiscCat:AddButton(displayName, function()
				local ok, err = pcall(function()
					loadstring(game:HttpGet(url, true))()
				end)
				if not ok then
					Window:Notification(3, "Failed: " .. tostring(err))
				end
			end)
		end
	end
end

--// ============================================================
--// Game Script (direct load by PlaceId)
--// ============================================================

do
	local path = "Scripts/Games/" .. tostring(PlaceId) .. ".luau"
	local ok, err = pcall(loadScript, path, Window, Esp)
	if ok then
		warn("[ChipLag] Loaded GameScript for place " .. tostring(PlaceId))
	else
		warn("[ChipLag] No GameScript for place " .. tostring(PlaceId) .. " (" .. tostring(err) .. ")")
		if Hub._GsCard then
			Hub._GsCard:SetSubtitle("GameScript: Error!")
		end
	end
end

--// ============================================================
--// Select Home tab on startup
--// ============================================================

Window:SelectTab("Home")
