local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")

local Stat = setmetatable({}, { __index = Control })
Stat.__index = Stat

local STYLES = { Normal = "Text", Accent = "Accent", Success = "Success", Danger = "Danger" }

function Stat.new(card, cfg)
	Validate.check("CreateStat", cfg, { Name = "string!", Value = "string|number", Style = "string" })
	local style = cfg.Style or "Normal"
	if not STYLES[style] then
		error(("[UI] CreateStat: Style must be Normal, Accent, Success or Danger (got '%s')"):format(style), 0)
	end
	local self = Control.base(card, cfg, "Stat", Stat)
	self.Header.Size = UDim2.new(1, 0, 0, self._ctx.Touch and 30 or 24)
	self:_addName(0)
	self._nameLabel.Size = UDim2.new(0.5, -4, 1, 0)
	self._style_ = style

	local value = Create.new("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.5, -4, 1, 0),
		Text = cfg.Value ~= nil and tostring(cfg.Value) or "",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = self.Header,
	})
	self:_style(value, "Medium", "Body")
	self._value = value

	self:_onRender(function(t)
		local c = t.Colors
		self._nameLabel.TextColor3 = self._disabled and c.TextMuted or c.TextDim
		value.TextColor3 = self._disabled and c.TextMuted or c[STYLES[style]]
	end)
	return self:_finish(cfg)
end

function Stat:Get()
	return self._value.Text
end

function Stat:Set(value)
	self._value.Text = tostring(value)
end

return Stat
