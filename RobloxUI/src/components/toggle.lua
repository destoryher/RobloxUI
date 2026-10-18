local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Tween = require("util/tween")

local Toggle = setmetatable({}, { __index = Control })
Toggle.__index = Toggle

local TRACK_W, TRACK_H, KNOB = 40, 22, 16

function Toggle.new(card, cfg)
	Validate.check("CreateToggle", cfg, {
		Name = "string!",
		Default = "boolean",
		Description = "string",
		Callback = "function",
		Disabled = "boolean",
		FireDefault = "boolean",
	})
	local self = Control.base(card, cfg, "Toggle", Toggle)
	local theme = self._ctx.Theme
	self._value = cfg.Default == true
	self:_addName(TRACK_W + 16)

	local track = Create.new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(TRACK_W, TRACK_H),
		Parent = self.Header,
	})
	Create.Corner(track, UDim.new(1, 0))
	local gradient = Create.new("UIGradient", { Enabled = false, Parent = track })
	theme:Bind(gradient, {
		Color = function(t)
			return ColorSequence.new(t.Colors.Accent, t.Colors.AccentAlt)
		end,
	})
	local stroke = Create.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = track,
	})
	local knob = Create.new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		Parent = track,
	})
	Create.Corner(knob, UDim.new(1, 0))

	local hit = Create.new("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = self.Header })
	self._maid:Give(hit.Activated:Connect(function()
		if not self._disabled then
			self:Set(not self._value)
		end
	end))

	self:_onRender(function(t, animate)
		local c = t.Colors
		local on = self._value
		gradient.Enabled = on
		local trackColor = on and Color3.new(1, 1, 1) or c.ControlPressed
		local knobColor = on and c.AccentText or c.TextDim
		local position = UDim2.new(0, on and (TRACK_W - KNOB - 3) or 3, 0.5, 0)
		local transparency = self._disabled and 0.55 or 0
		stroke.Color = on and c.Accent or c.Stroke
		track.BackgroundTransparency = transparency
		knob.BackgroundTransparency = transparency
		if animate then
			Tween.play(track, { BackgroundColor3 = trackColor }, t.Animation.Fast)
			Tween.play(knob, { Position = position, BackgroundColor3 = knobColor }, t.Animation.Fast)
		else
			track.BackgroundColor3 = trackColor
			knob.BackgroundColor3 = knobColor
			knob.Position = position
		end
	end)

	if cfg.FireDefault then
		self:_fire(self._value)
	end
	return self:_finish(cfg)
end

function Toggle:Get()
	return self._value
end

function Toggle:Set(value, silent)
	value = value and true or false
	if value == self._value then
		return
	end
	self._value = value
	self:_rerender(true)
	if not silent then
		self:_fire(value)
	end
end

return Toggle
