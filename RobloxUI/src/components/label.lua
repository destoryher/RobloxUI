local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")

local Label = setmetatable({}, { __index = Control })
Label.__index = Label

local STYLES = { Normal = "Text", Dim = "TextDim", Accent = "Accent", Danger = "Danger" }

function Label.new(card, cfg)
	Validate.check("CreateLabel", cfg, { Text = "string!", Style = "string" })
	local style = cfg.Style or "Normal"
	if not STYLES[style] then
		error(("[UI] CreateLabel: Style must be Normal, Dim, Accent or Danger (got '%s')"):format(style), 0)
	end

	local self = Control.base(card, cfg, "Label", Label)
	self.Header.AutomaticSize = Enum.AutomaticSize.Y
	self.Header.Size = UDim2.new(1, 0, 0, 0)

	local label = Create.new("TextLabel", {
		Name = "Text",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = cfg.Text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = self.Header,
	})
	Create.Padding(label, 0, 2, 0, 2)
	self._ctx.Theme:Bind(label, {
		Font = function(t)
			return t.Font.Regular
		end,
		TextSize = function(t)
			return t.TextSize.Small
		end,
	})
	self._nameLabel = label
	self:_onRender(function(t)
		label.TextColor3 = t.Colors[STYLES[style]]
	end)
	return self
end

function Label:Get()
	return self._name
end

function Label:Set(text)
	self:SetName(text)
end

return Label
