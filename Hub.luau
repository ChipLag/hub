--// Hub.luau
--// ChipLag Hub V2 - Main Orchestrator
--// Repository: https://github.com/ChipLag/hub

local repo = "https://raw.githubusercontent.com/ChipLag/hub/refs/heads/main/"

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

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
Hub._GsLabel = nil
Hub._TypesLabel = nil

--// ============================================================
--// Extend Window with script-specific API
--// ============================================================

-- Scripts call Window:Notification(duration, message)
function Window:Notification(duration, message)
	Window:Notify(tostring(message), tonumber(duration) or 3)
end

-- Scripts call Window:TypeTab(name) -> returns a Tab
function Window:TypeTab(name)
	local tab = Window:AddTab(name, 30 + Hub._TypesLoaded)
	Hub._TypesLoaded = Hub._TypesLoaded + 1
	if Hub._TypesLabel then
		Hub._TypesLabel:SetText("Types Loaded: " .. Hub._TypesLoaded)
	end
	return tab
end

-- Scripts call Window:GameScript(name) -> returns a Tab
function Window:GameScript(name)
	local tab = Window:AddTab(name, 20)
	Hub._GameScriptLoaded = true
	if Hub._GsLabel then
		Hub._GsLabel:SetText("GameScript: " .. name)
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

-- Player icon + welcome
local PlayerName = Player.DisplayName

local playerThumb = ""
pcall(function()
	playerThumb = Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)
if playerThumb ~= "" then
	HomeCat:AddImage(playerThumb, 40)
end

HomeCat:AddLabel("Welcome, " .. PlayerName .. "!")

-- Game name
local GameName = "Unknown"
pcall(function()
	GameName = MarketplaceService:GetProductInfo(PlaceId).Name
end)
HomeCat:AddLabel("Game: " .. GameName)

-- GameScript status
Hub._GsLabel = HomeCat:AddLabel("GameScript: None")

-- Types loaded
Hub._TypesLabel = HomeCat:AddLabel("Types Loaded: 0")

--// ============================================================
--// Script Types Tab
-- ============================================================

local TypesTab = Window:AddTab("Script Types", 2)
local TypesCat = TypesTab:AddCategory("Types")

local TypeRegistry = fetchScript("Scripts/Types.luau")
local GamesRegistry = fetchScript("Scripts/Games.luau")

local LoadedTypes = {} -- name -> { tab, cleanup, toggles }

if TypeRegistry then
	for displayName, fileName in pairs(TypeRegistry) do
		local toggle = TypesCat:AddToggle(displayName, false, function(state)
			if state then
				local ok, err = pcall(loadScript, "Scripts/Types/" .. fileName .. ".luau", Window, Esp)
				if not ok then
					warn("[ChipLag] Type load failed (" .. displayName .. "): " .. tostring(err))
					Window:Notify("Failed: " .. displayName .. " - " .. tostring(err), 5)
				else
					LoadedTypes[displayName] = true
				end
			else
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
			end
		end)
	end
end

--// ============================================================
--// Game Script
--// ============================================================

if GamesRegistry then
	for _, gameId in GamesRegistry do
		if gameId == PlaceId then
			local ok, err = pcall(loadScript, "Scripts/Games/" .. tostring(gameId) .. ".luau", Window, Esp)
			if not ok then
				warn("[ChipLag] GameScript load failed: " .. tostring(err))
				Window:Notify("GameScript failed: " .. tostring(err), 5)
			end
			break
		end
	end
end

--// ============================================================
--// Select Home tab on startup
--// ============================================================

Window:SelectTab("Home")
