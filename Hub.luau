--// Hub.luau
--// ChipLag Hub V2 - Main Orchestrator
--// Repository: https://github.com/ChipLag/hub

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

	local GameCard = HomeCat:AddCard(gameThumb, GameName, "GameScript: None", "Generic Scripts: 0 loaded")
	Hub._GsCard = GameCard
	Hub._TypesCard = GameCard

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
