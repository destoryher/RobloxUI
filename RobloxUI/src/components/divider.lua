local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")

local Divider = setmetatable({}, { __index = Control })
Divider.__index = Divider

function Divider.new(card, cfg)
	cfg = cfg or {}
	Validate.check("CreateDivider", cfg, { Text = "string" })
	cfg.Name = cfg.Text or ""
	local self = Control.base(card, cfg, "Divider", Divider)
	local theme = self._ctx.Theme
	self.Header.Size = UDim2.new(1, 0, 0, 16)

	local line = Create.new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = self.Header,
	})
	theme:Bind(line, { BackgroundColor3 = "Divider" })
	if cfg.Text then
		local label = Create.new("TextLabel", {
			Name = "Text",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = cfg.Text,
			BackgroundTransparency = 0,
			ZIndex = 2,
			Parent = self.Header,
		})
		Create.Padding(label, 0, 0, 8, 0)
		theme:Bind(label, { BackgroundColor3 = "Card" })
		theme:Text(label, "TextMuted", "Medium", "Small")
	end
	return self
end

return Divider
