--// ChipEsp.luau
--// Instance-based ESP Library (no Drawing API required)

local RunService = game:GetService("RunService")

local EspLibrary = {}

function EspLibrary.new()
	local Esp = {}
	Esp._Categories = {}

	local function makeBillboard(parent, text, color, offset)
		local bb = Instance.new("BillboardGui")
		bb.Name = "ChipEsp_Text"
		bb.Size = UDim2.new(0, 200, 0, 50)
		bb.StudsOffset = offset or Vector3.new(0, 2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 1000
		bb.Adornee = parent
		bb.Parent = parent

		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.BackgroundTransparency = 1
		tl.Text = tostring(text or "")
		tl.TextColor3 = color or Color3.new(1, 1, 1)
		tl.TextSize = 14
		tl.Font = Enum.Font.GothamBold
		tl.TextStrokeTransparency = 0.5
		tl.TextStrokeColor3 = Color3.new(0, 0, 0)
		tl.Parent = bb

		return bb, tl
	end

	--// Category
	function Esp:Category(name)
		if Esp._Categories[name] then
			return Esp._Categories[name]
		end

		local Cat = {}
		Cat._Name = name
		Cat._Objects = {}
		Cat._Visible = true

		function Cat:SetVisible(v)
			Cat._Visible = v
			for _, obj in Cat._Objects do
				if obj.SetVisible then obj:SetVisible(v) end
			end
		end

		function Cat:CreateBox(options)
			options = options or {}
			local Box = {}
			Box._ShouldShow = true
			Box._Position = nil
			Box._Size = options.Size or Vector3.new(4, 4, 4)
			Box._FillColor = options.FillColor or Color3.new(1, 0, 0)
			Box._Transparency = options.Transparency or 0
			Box._ShowText = options.ShowText

			local part = Instance.new("Part")
			part.Name = "ChipEsp_Box"
			part.Size = Box._Size
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Box._FillColor
			part.Transparency = Box._Transparency
			part.Parent = workspace
			Box._Part = part

			Box._Billboard = nil
			Box._TextLabel = nil
			if Box._ShowText then
				local bb, tl = makeBillboard(part, Box._ShowText, Box._FillColor, Vector3.new(0, Box._Size.Y * 0.5 + 1, 0))
				Box._Billboard = bb
				Box._TextLabel = tl
			end

			function Box:SetPosition(pos)
				Box._Position = pos
				if Box._Part then
					Box._Part.CFrame = CFrame.new(pos)
				end
			end

			function Box:SetSize(s)
				Box._Size = s
				if Box._Part then
					Box._Part.Size = s
				end
				if Box._Billboard then
					Box._Billboard.StudsOffset = Vector3.new(0, s.Y * 0.5 + 1, 0)
				end
			end

			function Box:SetVisible(v)
				Box._ShouldShow = v
				if Box._Part then
					Box._Part.Transparency = v and Box._Transparency or 1
				end
				if Box._Billboard then
					Box._Billboard.Enabled = v
				end
			end

			function Box:SetTransparency(t)
				Box._Transparency = t
				if Box._Part and Box._ShouldShow then
					Box._Part.Transparency = t
				end
			end

			function Box:Destroy()
				if Box._Part then Box._Part:Destroy() end
			end

			table.insert(Cat._Objects, Box)
			return Box
		end

		function Cat:CreateText(options)
			options = options or {}
			local Txt = {}
			Txt._ShouldShow = true
			Txt._Position = nil
			Txt._Color = options.Color or Color3.new(1, 1, 1)
			Txt._Size = options.Size or 14

			local part = Instance.new("Part")
			part.Name = "ChipEsp_TextPart"
			part.Size = Vector3.new(0.1, 0.1, 0.1)
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Parent = workspace
			Txt._Part = part

			local bb, tl = makeBillboard(part, options.Text, Txt._Color, Vector3.new(0, 0, 0))
			tl.TextSize = Txt._Size
			Txt._Billboard = bb
			Txt._TextLabel = tl

			function Txt:SetPosition(pos)
				Txt._Position = pos
				if Txt._Part then
					Txt._Part.CFrame = CFrame.new(pos)
				end
			end

			function Txt:SetText(t)
				if Txt._TextLabel then
					Txt._TextLabel.Text = tostring(t)
				end
			end

			function Txt:SetColor(c)
				if Txt._TextLabel then
					Txt._TextLabel.TextColor3 = c
				end
			end

			function Txt:SetVisible(v)
				Txt._ShouldShow = v
				if Txt._Billboard then
					Txt._Billboard.Enabled = v
				end
			end

			function Txt:Destroy()
				if Txt._Part then Txt._Part:Destroy() end
			end

			table.insert(Cat._Objects, Txt)
			return Txt
		end

		function Cat:Highlight(options)
			options = options or {}
			local HighlightObj = {}
			HighlightObj._ShouldShow = true
			HighlightObj._TargetPart = options.TargetPart
			HighlightObj._ShowText = options.ShowText
			HighlightObj._FillColor = options.FillColor or Color3.new(1, 0, 0)
			HighlightObj._BorderColor = options.BorderColor or Color3.new(1, 0, 0)
			HighlightObj._Transparency = options.Transparency or 0.5

			local hl = Instance.new("Highlight")
			hl.Name = "ChipEsp_Highlight"
			hl.FillColor = HighlightObj._FillColor
			hl.OutlineColor = HighlightObj._BorderColor
			hl.FillTransparency = HighlightObj._Transparency
			hl.OutlineTransparency = 0
			hl.Enabled = true
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Adornee = HighlightObj._TargetPart
			hl.Parent = workspace
			HighlightObj._Highlight = hl

			HighlightObj._Billboard = nil
			HighlightObj._TextLabel = nil
			if HighlightObj._ShowText then
				local bb, tl = makeBillboard(HighlightObj._TargetPart, HighlightObj._ShowText, HighlightObj._BorderColor, Vector3.new(0, 2, 0))
				HighlightObj._Billboard = bb
				HighlightObj._TextLabel = tl
			end

			function HighlightObj:SetVisible(v)
				HighlightObj._ShouldShow = v
				if HighlightObj._Highlight then
					HighlightObj._Highlight.Enabled = v
				end
				if HighlightObj._Billboard then
					HighlightObj._Billboard.Enabled = v
				end
			end

			function HighlightObj:SetTargetPart(part)
				HighlightObj._TargetPart = part
				if HighlightObj._Highlight then
					HighlightObj._Highlight.Adornee = part
				end
				if HighlightObj._Billboard then
					HighlightObj._Billboard.Adornee = part
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
					HighlightObj._Highlight = nil
				end
				if HighlightObj._Billboard then
					HighlightObj._Billboard:Destroy()
					HighlightObj._Billboard = nil
				end
			end

			table.insert(Cat._Objects, HighlightObj)
			return HighlightObj
		end

		Esp._Categories[name] = Cat
		return Cat
	end

	function Esp:Destroy()
		for _, cat in pairs(Esp._Categories) do
			for _, obj in cat._Objects do
				if obj.Destroy then obj:Destroy() end
			end
		end
		Esp._Categories = {}
	end

	return Esp
end

return EspLibrary
