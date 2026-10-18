local Create = require("util/create")

local Effects = {}

function Effects.shadow(window, main, scale)
	local theme = window.Theme
	local holder = Create.new("Frame", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = window._root,
	})
	local holderScale = Create.new("UIScale", { Parent = holder })

	local layers = {}
	for _, spec in ipairs({ { 4, 0.9 }, { 10, 0.94 }, { 18, 0.97 } }) do
		local grow = spec[1]
		local layer = Create.new("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = spec[2],
			Position = UDim2.fromOffset(-grow, -grow + 8),
			Size = UDim2.new(1, grow * 2, 1, grow * 2),
			Parent = holder,
		})
		layers[#layers + 1] = { corner = Create.new("UICorner", { Parent = layer }), grow = grow }
	end
	window._maid:Give(theme:Watch(function(t)
		for _, layer in ipairs(layers) do
			layer.corner.CornerRadius = UDim.new(0, t.Radius.Window + layer.grow)
		end
	end))

	local function sync()
		holder.AnchorPoint = main.AnchorPoint
		holder.Position = main.Position
		holder.Size = main.Size
		holder.Visible = main.Visible
		holderScale.Scale = scale.Scale
	end
	for _, signal in ipairs({
		main:GetPropertyChangedSignal("Position"),
		main:GetPropertyChangedSignal("Size"),
		main:GetPropertyChangedSignal("Visible"),
		scale:GetPropertyChangedSignal("Scale"),
	}) do
		window._maid:Give(signal:Connect(sync))
	end
	window._maid:Give(holder)
	sync()
end

function Effects.windowGlow(window, main)
	local theme = window.Theme
	local function glow(token, rotation)
		local frame = Create.new("Frame", {
			Name = "Glow",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			Parent = main,
		})
		theme:Corner(frame, "Window")
		theme:Bind(frame, { BackgroundColor3 = token })
		local gradient = Create.new("UIGradient", { Rotation = rotation, Parent = frame })
		theme:Bind(gradient, {
			Transparency = function(t)
				return NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.55, 1),
					NumberSequenceKeypoint.new(1, t.Transparency.Glow),
				})
			end,
		})
	end
	glow("Accent", 45)
	glow("AccentAlt", -45)
	Create.new("UIGradient", {
		Rotation = 125,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.8, 0.8, 0.8)),
		Parent = main,
	})
end

function Effects.sidebarGlow(window, sidebar)
	local theme = window.Theme
	local frame = Create.new("Frame", {
		Name = "BrandGlow",
		Size = UDim2.new(1, -1, 0, 150),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 1,
		Parent = sidebar,
	})
	theme:Corner(frame, "Window")
	local gradient = Create.new("UIGradient", { Rotation = 90, Parent = frame })
	theme:Bind(gradient, {
		Color = function(t)
			return ColorSequence.new(t.Colors.Accent, t.Colors.AccentAlt)
		end,
		Transparency = function(t)
			local start = t.Transparency.BrandGlow
			return NumberSequence.new({
				NumberSequenceKeypoint.new(0, start),
				NumberSequenceKeypoint.new(0.45, start + (1 - start) * 0.7),
				NumberSequenceKeypoint.new(1, 1),
			})
		end,
	})
end

function Effects.accentLine(window, parent, anchor, position, size)
	local line = Create.new("Frame", {
		Name = "AccentLine",
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		Parent = parent,
	})
	window.Theme:Bind(line, { BackgroundColor3 = "Accent" })
	Create.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = line,
	})
	return line
end

return Effects
