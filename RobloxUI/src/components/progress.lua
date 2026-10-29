local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Tween = require("util/tween")
local Fit = require("util/fit")

local Progress = setmetatable({}, { __index = Control })
Progress.__index = Progress

local function fmt(n)
	if n == math.floor(n) then
		return string.format("%d", n)
	end
	local text = string.format("%.2f", n)
	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")
	return text
end

function Progress.new(card, cfg)
	Validate.check("CreateProgress", cfg, {
		Name = "string!",
		Min = "number",
		Max = "number",
		Value = "number",
		Format = "string",
		Description = "string",
		Disabled = "boolean",
	})
	local min, max = cfg.Min or 0, cfg.Max or 100
	if max <= min then
		error("[UI] CreateProgress: Max must be greater than Min", 0)
	end
	local self = Control.base(card, cfg, "Progress", Progress)
	local theme = self._ctx.Theme
	self._min, self._max = min, max
	self._value = math.clamp(cfg.Value or min, min, max)
	self._format = cfg.Format or "{value} / {max}"

	self:_compactHeader()
	local valueLabel = Create.new("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 108, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = self.Header,
	})
	self:_style(valueLabel, "Medium", "Body")
	-- the value text gets the width it needs (up to half the row); the name gets the rest
	self:_addName(function(width)
		local needed = valueLabel.Text == "" and 0 or Fit.width(valueLabel.Text, valueLabel.TextSize, valueLabel.Font) + 2
		local valueW = math.min(needed, math.floor(width * 0.5))
		valueLabel.Size = UDim2.new(0, valueW, 1, 0)
		return valueW > 0 and valueW + 12 or 0
	end, { watch = { valueLabel } })

	local field = self:_addField(12)
	local track = Create.new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 8),
		Parent = field,
	})
	Create.Corner(track, UDim.new(1, 0))
	local fill = Create.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), Parent = track })
	Create.Corner(fill, UDim.new(1, 0))
	local fillGradient = Create.new("UIGradient", { Parent = fill })
	theme:Bind(fillGradient, {
		Color = function(t)
			return ColorSequence.new(t.Colors.Accent, t.Colors.AccentAlt)
		end,
	})

	self:_onRender(function(t, animate)
		local c = t.Colors
		local fraction = (self._value - self._min) / (self._max - self._min)
		track.BackgroundColor3 = c.Control
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		fill.BackgroundTransparency = self._disabled and 0.55 or 0
		valueLabel.TextColor3 = self._disabled and c.TextMuted or c.TextDim
		local vars = {
			value = fmt(self._value),
			max = fmt(self._max),
			percent = string.format("%d%%", math.floor(fraction * 100 + 0.5)),
		}
		valueLabel.Text = self._text or string.gsub(self._format, "{(%w+)}", function(key)
			return vars[key]
		end)
		if animate then
			Tween.play(fill, { Size = UDim2.fromScale(fraction, 1) }, t.Animation.Normal)
		else
			fill.Size = UDim2.fromScale(fraction, 1)
		end
	end)
	return self:_finish(cfg)
end

function Progress:Get()
	return self._value
end

function Progress:Set(value, text)
	if type(value) ~= "number" then
		error("[UI] Progress:Set expects a number", 0)
	end
	value = math.clamp(value, self._min, self._max)
	-- scripts often call Set every frame; skip the re-render and tween when nothing changed
	if value == self._value and text == self._text then
		return
	end
	self._value = value
	self._text = text
	self:_rerender(true)
end

function Progress:SetRange(min, max)
	if type(min) ~= "number" or type(max) ~= "number" or max <= min then
		error("[UI] Progress:SetRange expects numbers with max > min", 0)
	end
	self._min, self._max = min, max
	self._value = math.clamp(self._value, min, max)
	self:_rerender(true)
end

return Progress
