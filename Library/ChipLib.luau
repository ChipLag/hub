--// ChipLib.luau
--// Generic UI Library for ChipLag Hub V2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer

local function getUIParent()
	if gethui then
		return gethui()
	end
	return CoreGui
end

local function new(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			pcall(function() inst[k] = v end)
		end
	end
	if props.Parent then inst.Parent = props.Parent end
	return inst
end

local function isMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local Library = {}

function Library.new(options)
	options = options or {}

	local Lib = {}
	Lib._Theme = {
		Bg       = Color3.fromRGB(22, 22, 30),
		Sidebar  = Color3.fromRGB(16, 16, 22),
		SideHov  = Color3.fromRGB(30, 30, 42),
		SideSel  = Color3.fromRGB(42, 42, 58),
		Content  = Color3.fromRGB(26, 26, 36),
		Accent   = Color3.fromRGB(90, 150, 255),
		Text     = Color3.fromRGB(225, 225, 235),
		TextDim  = Color3.fromRGB(145, 145, 165),
		TogOn    = Color3.fromRGB(90, 150, 255),
		TogOff   = Color3.fromRGB(60, 60, 72),
		Elem     = Color3.fromRGB(34, 34, 46),
		ElemHov  = Color3.fromRGB(44, 44, 60),
		Border   = Color3.fromRGB(48, 48, 64),
		Notif    = Color3.fromRGB(30, 30, 42),
	}
	if options.Theme then
		for k, v in pairs(options.Theme) do
			Lib._Theme[k] = v
		end
	end
	local T = Lib._Theme

	Lib._Tabs = {}
	Lib._TabOrder = 10
	Lib._SidebarBtns = {}
	Lib._Pages = {}
	Lib._ActiveTab = nil
	Lib._Heartbeats = {}
	Lib._HeartbeatId = 0
	Lib._Visible = true
	Lib._Esp = nil

	Lib.Helpers = {}

	--// ScreenGui
	Lib.Gui = new("ScreenGui", {
		Name = options.Name or "ChipLib",
		DisplayOrder = 999,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = getUIParent(),
	})

	--// Main Frame (centered panel)
	Lib.Main = new("Frame", {
		Name = "Main",
		Size = UDim2.new(0, isMobile() and 380 or 880, 0, isMobile() and 540 or 460),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Bg,
		BorderSizePixel = 0,
		Visible = false,
		Parent = Lib.Gui,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = Lib.Main })
	new("UIStroke", { Color = T.Border, Thickness = 1, Parent = Lib.Main })

	local SidebarW = isMobile() and 120 or 180

	--// Sidebar
	local Sidebar = new("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SidebarW, 1, 0),
		BackgroundColor3 = T.Sidebar,
		BorderSizePixel = 0,
		Parent = Lib.Main,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = Sidebar,
	})
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
		Parent = Sidebar,
	})

	--// Tabs Scroll
	local TabsScroll = new("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Accent,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = Sidebar,
	})
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
		Parent = TabsScroll,
	})
	new("UIPadding", {
		PaddingBottom = UDim.new(0, 12),
		Parent = TabsScroll,
	})

	--// Content
	Lib.Content = new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -SidebarW - 1, 1, 0),
		Position = UDim2.new(0, SidebarW + 1, 0, 0),
		BackgroundColor3 = T.Content,
		BorderSizePixel = 0,
		Parent = Lib.Main,
	})

	local ContentScroll = new("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.new(1, -12, 1, -12),
		Position = UDim2.new(0, 6, 0, 6),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.Accent,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = Lib.Content,
	})
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		Parent = ContentScroll,
	})
	new("UIPadding", {
		PaddingBottom = UDim.new(0, 12),
		Parent = ContentScroll,
	})

	--// Notifications (on ScreenGui, not inside Main)
	local NotifHolder = new("Frame", {
		Name = "Notifications",
		Size = UDim2.new(0, 300, 1, -16),
		Position = UDim2.new(1, -310, 0, 8),
		BackgroundTransparency = 1,
		ZIndex = 100,
		Parent = Lib.Gui,
	})
	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Parent = NotifHolder,
	})

	--// Mobile Toggle Button
	if isMobile() then
		local ToggleBtn = new("TextButton", {
			Name = "MobileToggle",
			Size = UDim2.new(0, 56, 0, 56),
			Position = UDim2.new(1, -66, 1, -76),
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = T.Accent,
			BorderSizePixel = 0,
			Text = ":::",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			ZIndex = 200,
			Parent = Lib.Gui,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ToggleBtn })

		local dragging = false
		local dragStart, startPos, dragInput

		ToggleBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPos = ToggleBtn.Position
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
				local delta = input.Position - dragStart
				ToggleBtn.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)

		ToggleBtn.MouseButton1Click:Connect(function()
			Lib:Toggle()
		end)

		Lib.MobileBtn = ToggleBtn
	end

	--// ============================================================
	--// Element Factories
	--// ============================================================

	local function createToggle(parent, text, default, callback, order)
		local on = default or false

		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = T.Elem,
			BorderSizePixel = 0,
			LayoutOrder = order or 0,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 7), Parent = frame })

		local label = new("TextLabel", {
			Size = UDim2.new(1, -58, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})

		local bg = new("Frame", {
			Size = UDim2.new(0, 42, 0, 22),
			Position = UDim2.new(1, -54, 0.5, -11),
			BackgroundColor3 = on and T.TogOn or T.TogOff,
			BorderSizePixel = 0,
			Parent = frame,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bg })

		local dot = new("Frame", {
			Size = UDim2.new(0, 18, 0, 18),
			Position = on and UDim2.new(1, -20, 0, 2) or UDim2.new(0, 2, 0, 2),
			BackgroundColor3 = T.Text,
			BorderSizePixel = 0,
			Parent = bg,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })

		local obj = {}
		function obj:SetValue(v)
			on = v
			bg.BackgroundColor3 = on and T.TogOn or T.TogOff
			dot.Position = on and UDim2.new(1, -20, 0, 2) or UDim2.new(0, 2, 0, 2)
		end
		function obj:GetValue() return on end
		function obj:SetText(t) label.Text = t end
		function obj:SetCallback(fn) callback = fn end

		new("TextButton", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			Parent = frame,
		}).MouseButton1Click:Connect(function()
			on = not on
			obj:SetValue(on)
			if callback then callback(on) end
		end)

		return obj
	end

	local function createButton(parent, text, callback, order)
		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = T.Elem,
			BorderSizePixel = 0,
			Text = "   " .. text,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order or 0,
			AutoButtonColor = false,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 7), Parent = btn })

		btn.MouseEnter:Connect(function() btn.BackgroundColor3 = T.ElemHov end)
		btn.MouseLeave:Connect(function() btn.BackgroundColor3 = T.Elem end)
		btn.MouseButton1Click:Connect(function()
			if callback then callback() end
		end)

		local obj = {}
		function obj:SetText(t) btn.Text = "   " .. t end
		function obj:SetCallback(fn) callback = fn end
		return obj
	end

	local function createTextBox(parent, text, default, order)
		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = T.Elem,
			BorderSizePixel = 0,
			LayoutOrder = order or 0,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 7), Parent = frame })

		new("TextLabel", {
			Size = UDim2.new(0, 90, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})

		local input = new("TextBox", {
			Size = UDim2.new(1, -118, 0, 28),
			Position = UDim2.new(0, 100, 0, 7),
			BackgroundColor3 = T.Bg,
			BorderSizePixel = 0,
			Text = default or "",
			TextColor3 = T.Text,
			TextSize = 13,
			Font = Enum.Font.Gotham,
			ClearTextOnFocus = false,
			Parent = frame,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 5), Parent = input })

		local obj = { Value = default or "" }
		input:GetPropertyChangedSignal("Text"):Connect(function()
			obj.Value = input.Text
		end)
		function obj:GetValue() return obj.Value end
		function obj:SetValue(v) input.Text = v; obj.Value = v end
		return obj
	end

	local function createVector2(parent, text, default, order)
		local val = default or Vector2.new(0, 0)

		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = T.Elem,
			BorderSizePixel = 0,
			LayoutOrder = order or 0,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 7), Parent = frame })

		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})

		local function makeAxis(label, xPos, defaultVal)
			new("TextLabel", {
				Size = UDim2.new(0, 16, 0, 16),
				Position = UDim2.new(0, xPos, 0, 28),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = T.Accent,
				TextSize = 13,
				Font = Enum.Font.GothamBold,
				Parent = frame,
			})
			local tb = new("TextBox", {
				Size = UDim2.new(0, 60, 0, 24),
				Position = UDim2.new(0, xPos + 18, 0, 26),
				BackgroundColor3 = T.Bg,
				BorderSizePixel = 0,
				Text = tostring(defaultVal),
				TextColor3 = T.Text,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				ClearTextOnFocus = false,
				Parent = frame,
			})
			new("UICorner", { CornerRadius = UDim.new(0, 5), Parent = tb })
			return tb
		end

		local xTb = makeAxis("X", 14, val.X)
		local yTb = makeAxis("Y", 108, val.Y)

		local obj = { Value = val }

		function obj:ToXZ() return Vector3.new(obj.Value.X, 0, obj.Value.Y) end
		function obj:ToXY() return Vector2.new(obj.Value.X, obj.Value.Y) end
		function obj:ToYZ() return Vector3.new(0, obj.Value.X, obj.Value.Y) end
		function obj:GetValue() return obj.Value end
		function obj:SetValue(v)
			obj.Value = v
			xTb.Text = tostring(v.X)
			yTb.Text = tostring(v.Y)
		end

		local function update()
			local x = tonumber(xTb.Text) or 0
			local y = tonumber(yTb.Text) or 0
			obj.Value = Vector2.new(x, y)
		end

		xTb:GetPropertyChangedSignal("Text"):Connect(update)
		yTb:GetPropertyChangedSignal("Text"):Connect(update)

		return obj
	end

	local function createVector3(parent, text, default, order)
		local val = default or Vector3.new(0, 0, 0)

		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = T.Elem,
			BorderSizePixel = 0,
			LayoutOrder = order or 0,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 7), Parent = frame })

		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})

		local function makeAxis(label, xPos, defaultVal)
			new("TextLabel", {
				Size = UDim2.new(0, 16, 0, 16),
				Position = UDim2.new(0, xPos, 0, 28),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = T.Accent,
				TextSize = 13,
				Font = Enum.Font.GothamBold,
				Parent = frame,
			})
			local tb = new("TextBox", {
				Size = UDim2.new(0, 48, 0, 24),
				Position = UDim2.new(0, xPos + 18, 0, 26),
				BackgroundColor3 = T.Bg,
				BorderSizePixel = 0,
				Text = tostring(defaultVal),
				TextColor3 = T.Text,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				ClearTextOnFocus = false,
				Parent = frame,
			})
			new("UICorner", { CornerRadius = UDim.new(0, 5), Parent = tb })
			return tb
		end

		local xTb = makeAxis("X", 14, val.X)
		local yTb = makeAxis("Y", 90, val.Y)
		local zTb = makeAxis("Z", 166, val.Z)

		local obj = { Value = val }

		function obj:GetValue() return obj.Value end
		function obj:SetValue(v)
			obj.Value = v
			xTb.Text = tostring(v.X)
			yTb.Text = tostring(v.Y)
			zTb.Text = tostring(v.Z)
		end

		local function update()
			obj.Value = Vector3.new(
				tonumber(xTb.Text) or 0,
				tonumber(yTb.Text) or 0,
				tonumber(zTb.Text) or 0
			)
		end

		xTb:GetPropertyChangedSignal("Text"):Connect(update)
		yTb:GetPropertyChangedSignal("Text"):Connect(update)
		zTb:GetPropertyChangedSignal("Text"):Connect(update)

		return obj
	end

	local function createImage(parent, image, size, order)
		size = size or 48
		local img = new("ImageLabel", {
			Size = UDim2.new(0, size, 0, size),
			BackgroundTransparency = 1,
			Image = image or "",
			LayoutOrder = order or 0,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = img })
		local obj = {}
		function obj:SetImage(imgId) img.Image = imgId end
		return obj
	end

	local function createLabel(parent, text, order)
		local lbl = new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = "  " .. text,
			TextColor3 = T.TextDim,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order or 0,
			Parent = parent,
		})
		local obj = {}
		function obj:SetText(t) lbl.Text = "  " .. t end
		return obj
	end

	local function createLoopingToggle(parent, text, loopFunc, changeFunc, order)
		local on = false

		local frame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = T.Elem,
			BorderSizePixel = 0,
			LayoutOrder = order or 0,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 7), Parent = frame })

		local label = new("TextLabel", {
			Size = UDim2.new(1, -58, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})

		local bg = new("Frame", {
			Size = UDim2.new(0, 42, 0, 22),
			Position = UDim2.new(1, -54, 0.5, -11),
			BackgroundColor3 = T.TogOff,
			BorderSizePixel = 0,
			Parent = frame,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bg })

		local dot = new("Frame", {
			Size = UDim2.new(0, 18, 0, 18),
			Position = UDim2.new(0, 2, 0, 2),
			BackgroundColor3 = T.Text,
			BorderSizePixel = 0,
			Parent = bg,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })

		local id = Lib._HeartbeatId + 1
		Lib._HeartbeatId = id
		local conn = nil

		local function startLoop()
			if conn then conn:Disconnect() end
			conn = RunService.Heartbeat:Connect(function(dt)
				if on then pcall(loopFunc, dt) end
			end)
			Lib._Heartbeats[id] = { Connection = conn, Tab = nil }
		end

		local function stopLoop()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			Lib._Heartbeats[id] = nil
		end

		local obj = {}
		function obj:SetValue(v)
			on = v
			bg.BackgroundColor3 = on and T.TogOn or T.TogOff
			dot.Position = on and UDim2.new(1, -20, 0, 2) or UDim2.new(0, 2, 0, 2)
			if on then
				startLoop()
			else
				stopLoop()
			end
			if changeFunc then pcall(changeFunc, v) end
		end
		function obj:GetValue() return on end
		function obj:SetText(t) label.Text = t end
		function obj:SetCallback(fn) changeFunc = fn end
		function obj:SetTab(tabName)
			if Lib._Heartbeats[id] then
				Lib._Heartbeats[id].Tab = tabName
			end
		end
		function obj:Stop()
			stopLoop()
			obj:SetValue(false)
		end

		new("TextButton", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			Parent = frame,
		}).MouseButton1Click:Connect(function()
			obj:SetValue(not on)
		end)

		return obj
	end

	--// ============================================================
	--// Category Builder (shared between Tab and NoCategory)
	--// ============================================================

	local function buildCategory(catObj, catFrame, tabObj)
		catObj._Elements = {}
		catObj._OrderCounter = 0

		function catObj:AddToggle(text, default, callback)
			local order = catObj._OrderCounter; catObj._OrderCounter = order + 1
			local elem = createToggle(catFrame, text, default, callback, order)
			catObj._Elements[text] = elem
			return elem
		end

		function catObj:AddButton(text, callback)
			local order = catObj._OrderCounter; catObj._OrderCounter = order + 1
			return createButton(catFrame, text, callback, order)
		end

		function catObj:AddTextBox(text, default)
			local order = catObj._OrderCounter; catObj._OrderCounter = order + 1
			local elem = createTextBox(catFrame, text, default, order)
			catObj._Elements[text] = elem
			return elem
		end

		function catObj:AddVector2(text, default)
			local order = catObj._OrderCounter; catObj._OrderCounter = order + 1
			local elem = createVector2(catFrame, text, default, order)
			catObj._Elements[text] = elem
			return elem
		end

		function catObj:AddVector3(text, default)
			local order = catObj._OrderCounter; catObj._OrderCounter = order + 1
			local elem = createVector3(catFrame, text, default, order)
			catObj._Elements[text] = elem
			return elem
		end

		function catObj:AddLabel(text)
			local order = catObj._OrderCounter; catObj._OrderCounter = order + 1
			return createLabel(catFrame, text, order)
		end

		function catObj:AddImage(image, size)
			local order = catObj._OrderCounter; catObj._OrderCounter = order + 1
			return createImage(catFrame, image, size, order)
		end

		function catObj:AddLoopingToggle(text, loopFunc, changeFunc)
			local order = catObj._OrderCounter; catObj._OrderCounter = order + 1
			local elem = createLoopingToggle(catFrame, text, loopFunc, changeFunc, order)
			catObj._Elements[text] = elem
			if tabObj and tabObj._Name then
				elem:SetTab(tabObj._Name)
			end
			return elem
		end

		function catObj:Get(name)
			return catObj._Elements[name]
		end
	end

	--// ============================================================
	--// Tab Management
	--// ============================================================

	function Lib:AddTab(name, order)
		local tabOrder = order or Lib._TabOrder
		Lib._TabOrder = Lib._TabOrder + 1

		local Tab = {}
		Tab._Name = name
		Tab._Order = tabOrder
		Tab._Categories = {}
		Tab._CleanupFunc = nil

		local pageOrder = 0

		local btn = new("TextButton", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = T.Sidebar,
			BorderSizePixel = 0,
			Text = "   " .. name,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = tabOrder,
			AutoButtonColor = false,
			Parent = TabsScroll,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 7), Parent = btn })

		btn.MouseEnter:Connect(function()
			if Lib._ActiveTab ~= name then btn.BackgroundColor3 = T.SideHov end
		end)
		btn.MouseLeave:Connect(function()
			if Lib._ActiveTab ~= name then btn.BackgroundColor3 = T.Sidebar end
		end)

		local page = new("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = ContentScroll,
		})
		new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 5),
			Parent = page,
		})

		btn.MouseButton1Click:Connect(function()
			Lib:SelectTab(name)
		end)

		Lib._SidebarBtns[name] = btn
		Lib._Pages[name] = page
		Lib._Tabs[name] = Tab

		--// Category
		function Tab:AddCategory(catName)
			pageOrder = pageOrder + 1
			local Cat = {}

			local catFrame = new("Frame", {
				Name = catName,
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = pageOrder,
				Parent = page,
			})
			new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 5),
				Parent = catFrame,
			})

			pageOrder = pageOrder + 1
			local catHeader = new("Frame", {
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = Color3.new(T.Accent.R * 0.25, T.Accent.G * 0.25, T.Accent.B * 0.25),
				BorderSizePixel = 0,
				LayoutOrder = pageOrder,
				Parent = catFrame,
			})
			new("UICorner", { CornerRadius = UDim.new(0, 7), Parent = catHeader })
			new("TextLabel", {
				Size = UDim2.new(1, -12, 1, 0),
				Position = UDim2.new(0, 12, 0, 0),
				BackgroundTransparency = 1,
				Text = catName,
				TextColor3 = T.Accent,
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = catHeader,
			})

			buildCategory(Cat, catFrame, Tab)
			table.insert(Tab._Categories, Cat)
			return Cat
		end

		--// NoCategory
		function Tab:NoCategory()
			pageOrder = pageOrder + 1
			local Cat = {}

			local catFrame = new("Frame", {
				Name = "__nocat__",
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = pageOrder,
				Parent = page,
			})
			new("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
				Parent = catFrame,
			})

			buildCategory(Cat, catFrame, Tab)
			table.insert(Tab._Categories, Cat)
			return Cat
		end

		--// Cleanup
		function Tab:Cleanup(func)
			Tab._CleanupFunc = func
		end

		--// Destroy
		function Tab:Destroy()
			if Tab._CleanupFunc then pcall(Tab._CleanupFunc) end
			for id, hb in pairs(Lib._Heartbeats) do
				if hb.Tab == name then
					if hb.Connection then hb.Connection:Disconnect() end
					Lib._Heartbeats[id] = nil
				end
			end
			if page then page:Destroy() end
			if btn then btn:Destroy() end
			Lib._SidebarBtns[name] = nil
			Lib._Pages[name] = nil
			Lib._Tabs[name] = nil
		end

		return Tab
	end

	function Lib:RemoveTab(name)
		if Lib._Tabs[name] then
			Lib._Tabs[name]:Destroy()
		end
	end

	function Lib:SelectTab(name)
		for _, page in pairs(Lib._Pages) do
			page.Visible = false
		end
		for n, btn in pairs(Lib._SidebarBtns) do
			if n == Lib._ActiveTab then
				btn.BackgroundColor3 = T.Sidebar
			end
		end
		Lib._ActiveTab = name
		if Lib._SidebarBtns[name] then
			Lib._SidebarBtns[name].BackgroundColor3 = T.SideSel
		end
		if Lib._Pages[name] then
			Lib._Pages[name].Visible = true
		end
	end

	--// ============================================================
	--// Visibility
	--// ============================================================

	function Lib:Show()
		Lib.Main.Visible = true
		Lib._Visible = true
	end

	function Lib:Hide()
		Lib.Main.Visible = false
		Lib._Visible = false
	end

	function Lib:Toggle()
		if Lib._Visible then Lib:Hide() else Lib:Show() end
	end

	--// ============================================================
	--// Keybind toggle (RightControl on desktop)
	--// ============================================================

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.RightControl then
			Lib:Toggle()
		end
	end)

	--// ============================================================
	--// Notifications
	--// ============================================================

	function Lib:Notify(text, duration)
		duration = duration or 3
		local notif = new("Frame", {
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = T.Notif,
			BorderSizePixel = 0,
			Parent = NotifHolder,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = notif })
		new("Frame", {
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = T.Accent,
			BorderSizePixel = 0,
			Parent = notif,
		})
		new("TextLabel", {
			Size = UDim2.new(1, -18, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = T.Text,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Parent = notif,
		})
		task.delay(duration, function()
			if notif and notif.Parent then notif:Destroy() end
		end)
	end

	--// ============================================================
	--// Helpers
	--// ============================================================

	function Lib.Helpers:GetPlayer(name)
		if not name or name == "" then return nil end
		local lower = name:lower()
		if lower == "me" or lower == "local" or lower == "localplayer" then
			return Player
		end
		for _, p in Players:GetPlayers() do
			if p.DisplayName:sub(1, #name):lower() == lower then
				return p
			end
		end
		for _, p in Players:GetPlayers() do
			if p.Name:sub(1, #name):lower() == lower then
				return p
			end
		end
		return nil
	end

	--// ============================================================
	--// Auto-select Home if no tab selected
	--// ============================================================

	task.defer(function()
		if not Lib._ActiveTab then
			for name in pairs(Lib._Pages) do
				Lib:SelectTab(name)
				break
			end
		end
	end)

	return Lib
end

return Library
