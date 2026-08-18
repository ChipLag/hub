# ChipLag Hub V2 Library

---

## Table of Contents

1. [Loading the Hub](#loading-the-hub)
2. [Window (ChipLib)](#window-chiplib)
   - [Creating a Window](#creating-a-window)
   - [Tabs](#tabs)
   - [Categories](#categories)
   - [Elements](#elements)
   - [Helpers](#helpers)
   - [Notifications](#notifications)
   - [Visibility](#visibility)
3. [ESP (ChipEsp)](#esp-chipesp)
   - [Creating an ESP](#creating-an-esp)
   - [Categories](#esp-categories)
   - [CreateBox](#createbox)
   - [CreateText](#createtext)
   - [Highlight](#highlight)
   - [Destroying the ESP](#destroying-the-esp)
4. [Game Scripts](#game-scripts)
   - [What is a Game Script?](#what-is-a-game-script)
   - [Creating a Game Script](#creating-a-game-script)
   - [Script Structure](#script-structure)
   - [Available at Hub Load](#available-at-hub-load)
5. [Generic Scripts](#generic-scripts)
   - [What is a Generic Script?](#what-is-a-generic-script)
   - [Creating a Generic Script](#creating-a-generic-script)
   - [Script Structure](#generic-script-structure)
6. [Type Scripts](#type-scripts)
   - [What is a Type Script?](#what-is-a-type-script)
   - [Creating a Type Script](#creating-a-type-script)
   - [Registering a Type](#registering-a-type)
7. [Misc Scripts](#misc-scripts)
   - [What is a Misc Script?](#what-is-a-misc-script)
   - [Adding a Misc Script](#adding-a-misc-script)
8. [File Structure](#file-structure)
9. [Version History](#version-history)

---

## Loading the Hub

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ChipLag/hub/refs/heads/main/Hub.luau"))()
```

---

## Window (ChipLib)

### Creating a Window

The Window is created by the Hub automatically. Game Scripts and Generic Scripts receive it as the first vararg.

```lua
local Window, Esp = ...
```

### Tabs

Tabs appear in the sidebar. Each tab can have categories (sub-tabs) or elements directly.

```lua
local Tab = Window:AddTab("My Tab", order)
```

### Categories

Categories are sub-tabs within a tab. Clicking a category shows its elements.

```lua
local Cat = Tab:AddCategory("My Category")
```

If you don't need categories, put elements directly on the tab:

```lua
local CatTab = Tab:NoCategory()
```

### Elements

All element methods return an object you can interact with.

#### Toggle

```lua
local toggle = Cat:AddToggle("Enable Feature", false, function(value)
    print("Toggle is:", value)
end)

toggle:GetValue()   -- returns true/false
toggle:SetValue(true)
toggle:SetText("New Label")
toggle:SetCallback(function(value) end)
```

#### Button

```lua
local btn = Cat:AddButton("Click Me", function()
    print("Button clicked!")
end)

btn:SetText("New Label")
btn:SetCallback(function() end)
```

#### TextBox

```lua
local input = Cat:AddTextBox("Player Name", "default value")

input:GetValue()    -- returns string
input:SetValue("new value")
```

#### Slider

```lua
local slider = Cat:AddSlider("Speed", 1, 100, 50)

slider:GetValue()   -- returns number
slider:SetValue(75)
slider:SetCallback(function(value) end)
```

#### Vector2

```lua
local vec2 = Cat:AddVector2("Offset", Vector2.new(0, 0))

vec2:GetValue()     -- returns Vector2
vec2:SetValue(Vector2.new(10, 20))
vec2:ToXZ()         -- returns Vector3(x, 0, y)
vec2:ToXY()         -- returns Vector2(x, y)
vec2:ToYZ()         -- returns Vector3(0, x, y)
```

#### Vector3

```lua
local vec3 = Cat:AddVector3("Target Position", Vector3.new(0, 0, 0))

vec3:GetValue()     -- returns Vector3
vec3:SetValue(Vector3.new(100, 50, 200))
```

**Built-in buttons:**
- **Set here** — fills X/Y/Z with your character's HumanoidRootPart position (rounded)
- **Set null** — fills X/Y/Z with `2000000`

#### Label

```lua
local label = Cat:AddLabel("Status: Idle")

label:SetText("Status: Running")
```

#### Image

```lua
Cat:AddImage("rbxassetid://123456", 48) -- image id, size in pixels
```

#### Frame (CanvasGroup)

Useful for custom layouts or grouping elements.

```lua
local frame = Cat:AddFrame(UDim2.new(1, 0, 0, 100))
-- frame is a CanvasGroup, add children to it
```

#### LoopingToggle

Runs a function every Heartbeat while the toggle is ON.

```lua
local loop = Cat:AddLoopingToggle("ESP Update", function(dt)
    -- runs every frame while ON
    -- dt = delta time
end, function(value)
    -- runs when toggle changes
end)

loop:GetValue()
loop:SetValue(true)
loop:SetText("New Label")
loop:Stop()         -- turns off and stops the loop
loop:SetTab("TabName") -- associates with a tab for cleanup
```

### Helpers

```lua
local player = Window.Helpers:GetPlayer("username")
-- Returns player object, or nil if not found
-- Also accepts "me", "local", "localplayer" for LocalPlayer
```

### Notifications

```lua
Window:Notification(3, "Hello World!") -- duration, message
```

### Visibility

```lua
Window:Show()
Window:Hide()
Window:Toggle()     -- toggles visibility
```

RightControl keybind toggles the UI on desktop.

---

## ESP (ChipEsp)

### Creating an ESP

The ESP is created by the Hub automatically. Game Scripts receive it as the second vararg.

```lua
local Window, Esp = ...
```

### ESP Categories

Organize ESP objects into categories for bulk show/hide.

```lua
local Cat = Esp:Category("Players")

Cat:SetVisible(true)   -- show all objects in this category
Cat:SetVisible(false)  -- hide all objects in this category
```

### CreateBox

Creates a semi-transparent 3D box (filled Part) with optional text label.

```lua
local box = Cat:CreateBox({
    ShowText = "Player Name",    -- optional text above box
    FillColor = Color3.new(1, 0, 0),
    Transparency = 0.5,          -- 0 = opaque, 1 = invisible
    Size = Vector3.new(4, 4, 4), -- 3D size of the box
})

box:SetPosition(Vector3.new(0, 5, 0))
box:SetSize(Vector3.new(5, 5, 5))
box:SetTransparency(0.3)
box:SetVisible(true)
box:SetVisible(false)
box:Destroy()
```

**How it works:** Creates a `Part` with `Anchored = true`, `CanCollide = false`, `Material = SmoothPlastic`. A `BillboardGui` with `TextLabel` floats above it for `ShowText`.

### CreateText

Creates floating text at a world position.

```lua
local txt = Cat:CreateText({
    Text = "Hello",
    Color = Color3.new(1, 1, 1),
    Size = 14,
    Center = true,
})

txt:SetPosition(Vector3.new(0, 10, 0))
txt:SetText("New Text")
txt:SetColor(Color3.new(0, 1, 0))
txt:SetVisible(true)
txt:Destroy()
```

**How it works:** Creates an invisible `Part` at the world position with a `BillboardGui` + `TextLabel`.

### Highlight

Creates a Roblox Highlight instance on a part, with optional floating text.

```lua
local hl = Cat:Highlight({
    TargetPart = workspace.SomePart,
    ShowText = "Jail Cell",       -- optional
    BorderColor = Color3.new(1, 0, 0),
    FillColor = Color3.new(1, 0, 0),
    Transparency = 0.3,           -- 0 = opaque, 1 = invisible
})

hl:SetVisible(true)
hl:SetVisible(false)
hl:SetTargetPart(workspace.AnotherPart)
hl:SetTransparency(0.5)
hl:Destroy()
```

**How it works:** Creates `Instance.new("Highlight")` with `DepthMode = AlwaysOnTop`, parented to `workspace`. A `BillboardGui` with `TextLabel` is attached to the `TargetPart` for `ShowText`.

### Destroying the ESP

```lua
Esp:Destroy() -- destroys all categories, objects, and cleanup
```

---

## Game Scripts

### What is a Game Script?

A Game Script runs for a specific Roblox game (by PlaceId). It appears under the **GameScript** tab in the Hub. Each game can have one script.

### Creating a Game Script

Create a file in `Scripts/Games/` named with the game's PlaceId:

```
Scripts/Games/72231103877783.luau
```

### Script Structure

```lua
local Window, Esp = ... -- receive APIs via varargs

-- Create a GameScript tab (appears in the Hub)
local Gs = Window:GameScript("Build - Creative")

-- Add categories and elements
local Cat = Gs:AddCategory("My Features")

Cat:AddToggle("Auto Farm", false, function(value)
    -- toggle logic
end)

Cat:AddButton("Do Something", function()
    -- button logic
end)

-- Cleanup when the script is unloaded
Gs:Cleanup(function()
    -- disconnect events, destroy objects, etc.
end)

Window:Notification(5, "Script loaded!")
```

### Available at Hub Load

Game Scripts are loaded automatically when the Hub starts and the game matches the PlaceId. They are stored per-game and saved to `ChipLag/Generics/{PlaceId}.json`.

---

## Generic Scripts

### What is a Generic Script?

A Generic Script runs in **every game**. They appear under the **Generics** tab in the Hub. Users can toggle which generics are enabled per-game.

### Creating a Generic Script

Create a `.luau` file in `Scripts/Generics/`:

```
Scripts/Generics/InfiniteJump.luau
```

### Generic Script Structure

```lua
local Window, Esp = ... -- receive APIs via varargs

-- Create elements directly on a NoCategory tab
local Tab = Window:AddTab("My Generic")
local CatTab = Tab:NoCategory()

CatTab:AddToggle("Infinite Jump", false, function(value)
    -- toggle logic
end)

CatTab:AddButton("Fly", function()
    -- button logic
end)

Tab:Cleanup(function()
    -- cleanup logic
end)
```

---

## Type Scripts

### What is a Type Script?

A Type Script runs for a specific **game type** (not a specific PlaceId). Multiple games can share the same type. Type Scripts appear under the **Type** tab in the Hub.

### Creating a Type Script

Create a `.luau` file in `Scripts/Types/`:

```
Scripts/Types/CartRides.luau
```

### Registering a Type

Add the game type to the registry in `Scripts/Types.luau`:

```lua
return {
    ["Cart Rides"] = "CartRides",   -- display name = file name
    ["HD Admin Game"] = "HdAdmin",
}
```

### Type Script Structure

```lua
local Window, Esp = ... -- receive APIs via varargs

local Tab = Window:TypeTab("Cart Rides") -- matches the registry name

local CatTab = Tab:NoCategory()

CatTab:AddLoopingToggle("Fling", function()
    -- runs every frame while ON
end, function(value)
    -- runs when toggle changes
end)

Tab:Cleanup(function()
    -- cleanup logic
end)
```

---

## Misc Scripts

### What is a Misc Script?

A Misc Script is a standalone utility that appears under the **Misc** tab. They are registered in `Scripts/Misc.luau`.

### Adding a Misc Script

Edit `Scripts/Misc.luau` and add an entry:

```lua
return {
    { Name = "Script Name", Url = "https://raw.githubusercontent.com/..." },
}
```

The Hub will create a button in the Misc tab that loads the script when clicked.

---

## File Structure

```
ChipLagV2/
├── Hub.luau                    -- Main orchestrator
├── Library/
│   ├── ChipLib.luau            -- UI library
│   └── ChipEsp.luau            -- ESP library
├── Scripts/
│   ├── Types.luau              -- Type registry (name → file mapping)
│   ├── Misc.luau               -- Misc script registry
│   ├── Games/
│   │   └── {PlaceId}.luau      -- Per-game scripts (auto-loaded)
│   ├── Types/
│   │   ├── CartRides.luau      -- Type-specific scripts
│   │   └── HdAdmin.luau
│   └── Generics/
│       └── *.luau              -- Universal scripts (run everywhere)
└── LIBRARY.md                  -- This file
```

---

## Version History

- **V2.2.0** — Scale-based UI, Instance-based ESP (no Drawing API), Vector3 with Set here/Set null buttons
- **V2.1.6** — Fixed Highlight, Box transparency, Hub layout
- **V2.1.4** — Added Misc tab, CartRides fling fix, HD Admin jail highlights
