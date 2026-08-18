--// ChipEsp.luau
--// Generic ESP Drawing Library for ChipLag Hub V2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local EspLibrary = {}

function EspLibrary.new()
	local Esp = {}
	Esp._Categories = {}
	Esp._AllObjects = {}
	Esp._UpdateConn = nil

	--// Update Loop
	local function updateBox(obj, cat)
		if not obj._Position then return end

		local pos = obj._Position
		local size = obj._Size
		local half = size * 0.5

		local corners3D = {
			pos + Vector3.new(-half.X, -half.Y, -half.Z),
			pos + Vector3.new( half.X, -half.Y, -half.Z),
			pos + Vector3.new( half.X,  half.Y, -half.Z),
			pos + Vector3.new(-half.X,  half.Y, -half.Z),
			pos + Vector3.new(-half.X, -half.Y,  half.Z),
			pos + Vector3.new( half.X, -half.Y,  half.Z),
			pos + Vector3.new( half.X,  half.Y,  half.Z),
			pos + Vector3.new(-half.X,  half.Y,  half.Z),
		}

		local projected = {}
		local anyOnScreen = false
		for i, c in corners3D do
			local sp, onScreen = Camera:WorldToViewportPoint(c)
			projected[i] = Vector2.new(sp.X, sp.Y)
			if onScreen then anyOnScreen = true end
		end

		local visible = cat._Visible and obj._ShouldShow and anyOnScreen

		local edges = {
			{1,2}, {2,3}, {3,4}, {4,1},
			{5,6}, {6,7}, {7,8}, {8,5},
			{1,5}, {2,6}, {3,7}, {4,8},
		}

		for i, edge in edges do
			local line = obj._Lines[i]
			if line then
				if visible then
					line.From = projected[edge[1]]
					line.To = projected[edge[2]]
					line.Visible = true
				else
					line.Visible = false
				end
			end
		end

		if obj._TextLabel then
			if visible and obj._ShowText then
				local sp = Camera:WorldToViewportPoint(pos + Vector3.new(0, half.Y + 1, 0))
				obj._TextLabel.Position = Vector2.new(sp.X, sp.Y)
				obj._TextLabel.Visible = true
			else
				obj._TextLabel.Visible = false
			end
		end
	end

	local function updateText(obj, cat)
		if not obj._Position then return end
		local sp, onScreen = Camera:WorldToViewportPoint(obj._Position)
		local visible = cat._Visible and obj._ShouldShow and onScreen
		if visible then
			obj._Drawing.Position = Vector2.new(sp.X, sp.Y)
			obj._Drawing.Visible = true
		else
			obj._Drawing.Visible = false
		end
	end

	--// Category
	function Esp:Category(name)
		local Cat = {}
		Cat._Name = name
		Cat._Objects = {}
		Cat._Visible = true

		function Cat:SetVisible(v)
			Cat._Visible = v
			for _, obj in Cat._Objects do
				if obj._Lines then
					for _, line in obj._Lines do
						line.Visible = false
					end
				end
				if obj._TextLabel then
					obj._TextLabel.Visible = false
				end
				if obj._Drawing then
					obj._Drawing.Visible = false
				end
			end
		end

		function Cat:CreateBox(options)
			options = options or {}
			local Box = {}
			Box._ShouldShow = true
			Box._Position = nil
			Box._Size = options.Size or Vector3.new(4, 4, 4)
			Box._FillColor = options.FillColor or Color3.new(1, 0, 0)
			Box._BorderColor = options.BorderColor or options.FillColor or Color3.new(1, 0, 0)
			Box._Transparency = options.Transparency or 0
			Box._ShowText = options.ShowText
			Box._Lines = {}
			Box._TextLabel = nil

			for i = 1, 12 do
				local line = Drawing.new("Line")
				line.Visible = false
				line.Color = Box._BorderColor
				line.Thickness = 1.5
				line.Transparency = 1 - Box._Transparency
				Box._Lines[i] = line
			end

			if Box._ShowText then
				local txt = Drawing.new("Text")
				txt.Visible = false
				txt.Color = Box._FillColor
				txt.Size = 14
				txt.Center = true
				txt.Outline = true
				txt.OutlineColor = Color3.new(0, 0, 0)
				txt.Text = tostring(Box._ShowText)
				Box._TextLabel = txt
			end

			function Box:SetPosition(pos)
				Box._Position = pos
			end

			function Box:SetSize(s)
				Box._Size = s
			end

			function Box:SetVisible(v)
				Box._ShouldShow = v
			end

			function Box:SetTransparency(t)
				Box._Transparency = t
				for _, line in Box._Lines do
					line.Transparency = 1 - t
				end
			end

			function Box:Destroy()
				for _, line in Box._Lines do line:Remove() end
				if Box._TextLabel then Box._TextLabel:Remove() end
			end

			table.insert(Cat._Objects, Box)
			table.insert(Esp._AllObjects, { obj = Box, cat = Cat, kind = "box" })
			return Box
		end

		function Cat:CreateText(options)
			options = options or {}
			local Txt = {}
			Txt._ShouldShow = true
			Txt._Position = nil
			Txt._Color = options.Color or Color3.new(1, 1, 1)
			Txt._Size = options.Size or 14

			local d = Drawing.new("Text")
			d.Visible = false
			d.Color = Txt._Color
			d.Size = Txt._Size
			d.Center = options.Center or false
			d.Outline = true
			d.OutlineColor = Color3.new(0, 0, 0)
			d.Text = options.Text or ""
			Txt._Drawing = d

			function Txt:SetPosition(pos) Txt._Position = pos end
			function Txt:SetText(t) Txt._Drawing.Text = tostring(t) end
			function Txt:SetColor(c) Txt._Drawing.Color = c end
			function Txt:SetVisible(v) Txt._ShouldShow = v end
			function Txt:Destroy() Txt._Drawing:Remove() end

			table.insert(Cat._Objects, Txt)
			table.insert(Esp._AllObjects, { obj = Txt, cat = Cat, kind = "text" })
			return Txt
		end

		function Cat:Highlight(options)
			options = options or {}
			local HighlightObj = {}
			HighlightObj._ShouldShow = true
			HighlightObj._TargetPart = options.TargetPart
			HighlightObj._ShowText = options.ShowText or nil
			HighlightObj._BorderColor = options.BorderColor or Color3.new(1, 0, 0)
			HighlightObj._FillColor = options.FillColor or Color3.new(1, 0, 0)
			HighlightObj._Transparency = options.Transparency or 0.5

			local hl = Instance.new("Highlight")
			hl.Adornee = HighlightObj._TargetPart
			hl.FillColor = HighlightObj._FillColor
			hl.OutlineColor = HighlightObj._BorderColor
			hl.FillTransparency = HighlightObj._Transparency
			hl.Enabled = true
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent = workspace
			HighlightObj._Highlight = hl

			if HighlightObj._ShowText then
				local txt = Drawing.new("Text")
				txt.Visible = false
				txt.Color = HighlightObj._BorderColor
				txt.Size = 14
				txt.Center = true
				txt.Outline = true
				txt.OutlineColor = Color3.new(0, 0, 0)
				txt.Text = tostring(HighlightObj._ShowText)
				HighlightObj._TextLabel = txt
			end

			function HighlightObj:SetVisible(v)
				HighlightObj._ShouldShow = v
				if HighlightObj._Highlight then
					HighlightObj._Highlight.Enabled = v
				end
				if HighlightObj._TextLabel then
					HighlightObj._TextLabel.Visible = false
				end
			end

			function HighlightObj:SetTargetPart(part)
				HighlightObj._TargetPart = part
				if HighlightObj._Highlight then
					HighlightObj._Highlight.Adornee = part
				end
			end

			function HighlightObj:SetTransparency(t)
				HighlightObj._Transparency = t
				if HighlightObj._Highlight then
					HighlightObj._Highlight.FillTransparency = t
				end
			end

			function HighlightObj:Destroy()
				if HighlightObj._Highlight then
					HighlightObj._Highlight:Destroy()
				end
				if HighlightObj._TextLabel then
					HighlightObj._TextLabel:Remove()
				end
			end

			table.insert(Cat._Objects, HighlightObj)
			table.insert(Esp._AllObjects, { obj = HighlightObj, cat = Cat, kind = "highlight" })
			return HighlightObj
		end

		Esp._Categories[name] = Cat
		return Cat
	end

	--// Render loop
	local function updateHighlight(obj, cat)
		if not obj._TargetPart then return end
		local visible = cat._Visible and obj._ShouldShow and obj._Highlight and obj._Highlight.Adornee and obj._Highlight.Adornee.Parent ~= nil
		if obj._Highlight then
			obj._Highlight.Enabled = visible
		end
		if obj._TextLabel and visible then
			local pos = obj._TargetPart.Position
			local sp, onScreen = Camera:WorldToViewportPoint(pos + Vector3.new(0, 2, 0))
			if onScreen then
				obj._TextLabel.Position = Vector2.new(sp.X, sp.Y)
				obj._TextLabel.Visible = true
			else
				obj._TextLabel.Visible = false
			end
		elseif obj._TextLabel then
			obj._TextLabel.Visible = false
		end
	end

	Esp._UpdateConn = RunService.RenderStepped:Connect(function()
		Camera = workspace.CurrentCamera
		for _, entry in Esp._AllObjects do
			if entry.kind == "box" then
				pcall(updateBox, entry.obj, entry.cat)
			elseif entry.kind == "text" then
				pcall(updateText, entry.obj, entry.cat)
			elseif entry.kind == "highlight" then
				pcall(updateHighlight, entry.obj, entry.cat)
			end
		end
	end)

	--// Cleanup
	function Esp:Destroy()
		if Esp._UpdateConn then Esp._UpdateConn:Disconnect() end
		for _, entry in Esp._AllObjects do
			if entry.obj.Destroy then entry.obj:Destroy() end
		end
		Esp._AllObjects = {}
		Esp._Categories = {}
	end

	return Esp
end

return EspLibrary
