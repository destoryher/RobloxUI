local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Tween = require("util/tween")
local Pointer = require("util/pointer")

local Slider = setmetatable({}, { __index = Control })
Slider.__index = Slider

local function decimalsOf(increment)
	local text = string.format("%.4f", increment)
	text = text:gsub("0+$", "")
	text = text:gsub("%.$", "")
	local dot = text:find("%.")
	return dot and (#text - dot) or 0
end

function Slider.new(card, cfg)
	Validate.check("CreateSlider", cfg, {
		Name = "string!",
		Min = "number!",
		Max = "number!",
		Increment = "number",
		Default = "number",
		Suffix = "string",
		Description = "string",
		Callback = "function",
		Disabled = "boolean",
		FireDefault = "boolean",
	})
	if cfg.Max <= cfg.Min then
		error("[UI] CreateSlider: Max must be greater than Min", 0)
	end
	local increment = cfg.Increment or 1
	if increment <= 0 then
		error("[UI] CreateSlider: Increment must be greater than 0", 0)
	end

	local self = Control.base(card, cfg, "Slider", Slider)
	local ctx = self._ctx
	local theme = ctx.Theme
	self._min, self._max, self._inc = cfg.Min, cfg.Max, increment
	self._dec = math.min(decimalsOf(increment), 4)
	self._suffix = cfg.Suffix or ""
	self._value = self:_snap(cfg.Default or cfg.Min)

	self:_compactHeader()
	self:_addName(96)

	local valueBox = Create.new("TextBox", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(88, 24),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = self.Header,
	})
	self:_style(valueBox, "Medium", "Body")

	local field = self:_addField(ctx.Touch and 28 or 20)
	local knobSize = ctx.Touch and 18 or 14
	local track = Create.new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, knobSize / 2, 0.5, 0),
		Size = UDim2.new(1, -knobSize, 0, 6),
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
	local knob = Create.new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(knobSize, knobSize),
		ZIndex = 2,
		Parent = track,
	})
	Create.Corner(knob, UDim.new(1, 0))
	local knobStroke = Create.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 2, Parent = knob })
	local hit = Create.new("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = field })

	local page = card._tab.Page
	Pointer.bind(hit, {
		OnBegin = function()
			if not self._disabled then
				page.ScrollingEnabled = false
			end
		end,
		OnMove = function(position)
			if self._disabled then
				return
			end
			local width = math.max(track.AbsoluteSize.X, 1)
			local fraction = math.clamp((position.X - track.AbsolutePosition.X) / width, 0, 1)
			self:_setValue(self._min + fraction * (self._max - self._min), false, false, true)
		end,
		OnEnd = function()
			page.ScrollingEnabled = true
			self:_flush()
		end,
	}, self._maid)

	self._maid:Give(valueBox.Focused:Connect(function()
		valueBox.Text = self:_format(self._value, false)
	end))
	self._maid:Give(valueBox.FocusLost:Connect(function()
		local parsed = tonumber(string.match(valueBox.Text, "-?%d*%.?%d+"))
		if parsed and not self._disabled then
			self:_setValue(parsed, false, true)
		end
		self:_rerender(false)
	end))

	self:_onRender(function(t, animate)
		local c = t.Colors
		local fraction = (self._value - self._min) / (self._max - self._min)
		track.BackgroundColor3 = c.Control
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		knob.BackgroundColor3 = c.Text
		knobStroke.Color = c.Accent
		local transparency = self._disabled and 0.55 or 0
		track.BackgroundTransparency = transparency
		fill.BackgroundTransparency = transparency
		knob.BackgroundTransparency = transparency
		valueBox.TextColor3 = self._disabled and c.TextMuted or c.TextDim
		if not valueBox:IsFocused() then
			valueBox.Text = self:_format(self._value, true)
		end
		if animate then
			Tween.play(fill, { Size = UDim2.fromScale(fraction, 1) }, t.Animation.Fast)
			Tween.play(knob, { Position = UDim2.fromScale(fraction, 0.5) }, t.Animation.Fast)
		else
			fill.Size = UDim2.fromScale(fraction, 1)
			knob.Position = UDim2.fromScale(fraction, 0.5)
		end
	end)

	if cfg.FireDefault then
		self:_fire(self._value)
	end
	return self:_finish(cfg)
end

function Slider:_snap(value)
	value = math.clamp(value, self._min, self._max)
	value = self._min + math.floor((value - self._min) / self._inc + 0.5) * self._inc
	value = math.clamp(value, self._min, self._max)
	return tonumber(string.format("%." .. self._dec .. "f", value))
end

function Slider:_format(value, withSuffix)
	return string.format("%." .. self._dec .. "f", value) .. (withSuffix and self._suffix or "")
end

local FIRE_INTERVAL = 0.05

function Slider:_fireThrottled(value)
	local now = os.clock()
	if now - (self._lastFire or 0) >= FIRE_INTERVAL then
		self._lastFire, self._pending = now, nil
		self:_fire(value)
	else
		self._pending = value
	end
end

function Slider:_flush()
	local value = self._pending
	if value ~= nil then
		self._pending = nil
		self._lastFire = os.clock()
		self:_fire(value)
	end
end

function Slider:_setValue(raw, silent, animate, throttle)
	local value = self:_snap(raw)
	if value == self._value then
		return
	end
	self._value = value
	self:_rerender(animate)
	if not silent then
		if throttle then
			self:_fireThrottled(value)
		else
			self:_fire(value)
		end
	end
end

function Slider:Get()
	return self._value
end

function Slider:Set(value, silent)
	if type(value) ~= "number" then
		error("[UI] Slider:Set expects a number", 0)
	end
	self:_setValue(value, silent, true)
end

return Slider
