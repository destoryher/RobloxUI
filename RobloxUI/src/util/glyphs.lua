local Create = require("util/create")

local Glyphs = {}

function Glyphs.paint(parts, color)
	for _, part in ipairs(parts) do
		part.inst[part.prop] = color
	end
end

local function holder(parent, size)
	return Create.new("Frame", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
end

local function bar(parent, parts, width, height, x, y, rotation)
	local frame = Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, height),
		Rotation = rotation or 0,
		Parent = parent,
	})
	parts[#parts + 1] = { inst = frame, prop = "BackgroundColor3" }
	return frame
end

function Glyphs.mark(parent, style, size, theme)
	size = size or 24
	local box = holder(parent, size)
	local function color(inst, token)
		if theme then
			theme:Bind(inst, { BackgroundColor3 = token })
		else
			inst.BackgroundColor3 = Color3.new(1, 1, 1)
		end
	end
	local function piece(width, height, rotation, token, radius)
		local frame = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, height),
			Rotation = rotation,
			Parent = box,
		})
		Create.Corner(frame, radius)
		color(frame, token)
		return frame
	end

	if style == "Diamond" then
		piece(size * 0.62, size * 0.62, 45, "Accent", size * 0.12)
		piece(size * 0.28, size * 0.28, 45, "AccentAlt", size * 0.06)
	elseif style == "Ring" then
		local ring = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size * 0.8, size * 0.8),
			BackgroundTransparency = 1,
			Parent = box,
		})
		Create.Corner(ring, UDim.new(1, 0))
		local stroke = Create.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Thickness = math.max(2, size * 0.14),
			Color = Color3.new(1, 1, 1),
			Parent = ring,
		})
		if theme then
			theme:Bind(stroke, { Color = "Accent" })
		end
		piece(size * 0.26, size * 0.26, 0, "AccentAlt", UDim.new(1, 0))
	elseif style == "Dot" then
		piece(size * 0.72, size * 0.72, 0, "Accent", UDim.new(1, 0))
		piece(size * 0.3, size * 0.3, 0, "AccentAlt", UDim.new(1, 0))
	else
		piece(size * 0.94, size * 0.2, 45, "Accent", UDim.new(1, 0))
		piece(size * 0.94, size * 0.2, -45, "AccentAlt", UDim.new(1, 0))
	end
	return box
end

function Glyphs.magnifier(parent, size)
	size = size or 16
	local box, parts = holder(parent, size), {}
	local ringSize = math.floor(size * 0.64)
	local ring = Create.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(ringSize, ringSize), Parent = box })
	Create.Corner(ring, UDim.new(1, 0))
	local stroke = Create.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1.5, Parent = ring })
	parts[#parts + 1] = { inst = stroke, prop = "Color" }
	local length = size * 0.34
	local center = ringSize / 2 + (ringSize / 2 + length / 2) * 0.7071
	bar(box, parts, length, 2, center, center, 45)
	return box, parts
end

function Glyphs.square(parent, size)
	size = size or 16
	local box, parts = holder(parent, size), {}
	local side = math.floor(size * 0.7)
	local square = Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(side, side),
		Parent = box,
	})
	Create.Corner(square, 2)
	local stroke = Create.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1.5, Parent = square })
	parts[#parts + 1] = { inst = stroke, prop = "Color" }
	return box, parts
end

function Glyphs.cross(parent, size)
	size = size or 16
	local box, parts = holder(parent, size), {}
	local length = size * 0.85
	bar(box, parts, length, 2, size / 2, size / 2, 45)
	bar(box, parts, length, 2, size / 2, size / 2, -45)
	return box, parts
end

function Glyphs.move(parent, size)
	size = size or 18
	local box, parts = holder(parent, size), {}
	local half = size / 2
	bar(box, parts, size * 0.78, 2, half, half, 0)
	bar(box, parts, 2, size * 0.78, half, half, 0)
	local tip = size * 0.26
	for _, point in ipairs({ { half, tip / 2 }, { half, size - tip / 2 }, { tip / 2, half }, { size - tip / 2, half } }) do
		bar(box, parts, tip, tip, point[1], point[2], 45)
	end
	return box, parts
end

return Glyphs
