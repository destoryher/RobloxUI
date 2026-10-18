local Create = {}

local WHITE = Color3.new(1, 1, 1)

local DEFAULTS = {
	Frame = { BorderSizePixel = 0 },
	TextLabel = {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
	},
	TextButton = {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = WHITE,
	},
	TextBox = {
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
	},
	ImageLabel = { BorderSizePixel = 0, BackgroundTransparency = 1 },
	ImageButton = { BorderSizePixel = 0, BackgroundTransparency = 1, AutoButtonColor = false },
	ScrollingFrame = { BorderSizePixel = 0, BackgroundTransparency = 1 },
}

function Create.new(class, props, children)
	local inst = Instance.new(class)
	local defaults = DEFAULTS[class]
	if defaults then
		for key, value in pairs(defaults) do
			inst[key] = value
		end
	end
	local parent
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				inst[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function toUDim(radius)
	if typeof(radius) == "UDim" then
		return radius
	end
	return UDim.new(0, radius)
end

function Create.Corner(parent, radius)
	return Create.new("UICorner", { CornerRadius = toUDim(radius), Parent = parent })
end

function Create.Padding(parent, left, top, right, bottom)
	left = left or 0
	top = top or left
	right = right or left
	bottom = bottom or top
	return Create.new("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		Parent = parent,
	})
end

function Create.List(parent, direction, gap)
	return Create.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

return Create
