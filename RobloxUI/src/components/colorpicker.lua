local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Pointer = require("util/pointer")
local Popup = require("core/popup")

local ColorPicker = setmetatable({}, { __index = Control })
ColorPicker.__index = ColorPicker

local HUE_STOPS = {
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
}

function ColorPicker.new(card, cfg)
	Validate.check("CreateColorPicker", cfg, {
		Name = "string!",
		Default = "Color3",
		Description = "string",
		Callback = "function",
		Disabled = "boolean",
		FireDefault = "boolean",
	})
	local self = Control.base(card, cfg, "ColorPicker", ColorPicker)
	local theme = self._ctx.Theme
	self._color = cfg.Default or Color3.new(1, 1, 1)
	self._h, self._s, self._v = self._color:ToHSV()
	self._open = false
	self:_addName(60)

	local swatch = Create.new("TextButton", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(44, 24),
		BackgroundTransparency = 0,
		Parent = self.Header,
	})
	theme:Corner(swatch, "Control")
	local stroke = theme:Stroke(swatch, "Stroke", 1)
	self._swatch = swatch

	self._maid:Give(swatch.Activated:Connect(function()
		if self._open then
			self._popup.Close()
		else
			self:_openPopup()
		end
	end))

	self:_onRender(function(t)
		swatch.BackgroundColor3 = self._color
		swatch.BackgroundTransparency = self._disabled and 0.5 or 0
		stroke.Color = self._open and t.Colors.Accent or t.Colors.Stroke
	end)

	if cfg.FireDefault then
		self:_fire(self._color)
	end
	return self:_finish(cfg)
end

function ColorPicker:Get()
	return self._color
end

local FIRE_INTERVAL = 0.05

function ColorPicker:_flush()
	local color = self._pending
	if color then
		self._pending = nil
		self._lastFire = os.clock()
		self:_fire(color)
	end
end

function ColorPicker:_update(h, s, v, silent, throttle)
	self._h, self._s, self._v = h, s, v
	self._color = Color3.fromHSV(h, s, v)
	self:_rerender(false)
	self:_syncPicker()
	if not silent then
		if throttle then
			local now = os.clock()
			if now - (self._lastFire or 0) >= FIRE_INTERVAL then
				self._lastFire, self._pending = now, nil
				self:_fire(self._color)
			else
				self._pending = self._color
			end
		else
			self:_fire(self._color)
		end
	end
end

function ColorPicker:Set(color, silent)
	if typeof(color) ~= "Color3" then
		error("[UI] ColorPicker:Set expects a Color3", 0)
	end
	if color == self._color then
		return
	end
	local h, s, v = color:ToHSV()
	if s > 0.001 and v > 0.001 then
		self._h = h
	end
	self:_update(self._h, s, v, silent)
end

function ColorPicker:_syncPicker()
	local picker = self._picker
	if not picker then
		return
	end
	picker.SVBase.BackgroundColor3 = Color3.fromHSV(self._h, 1, 1)
	picker.SVCursor.Position = UDim2.fromScale(self._s, 1 - self._v)
	picker.HueCursor.Position = UDim2.fromScale(self._h, 0.5)
	if not picker.Hex:IsFocused() then
		picker.Hex.Text = "#" .. string.upper(self._color:ToHex())
	end
end

function ColorPicker:_openPopup()
	if self._disabled or self._open then
		return
	end
	local theme = self._ctx.Theme
	local popup = Popup.open(self._ctx.Window, self._swatch, {
		Width = 232,
		Height = 204,
		AlignRight = true,
		OnClose = function()
			self:_flush()
			self._open = false
			self._popup, self._picker = nil, nil
			self:_rerender(true)
		end,
	})
	self._popup, self._open = popup, true
	self:_rerender(true)

	local body = popup.Body
	local sv = Create.new("Frame", {
		Name = "SV",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 124),
		Parent = body,
	})
	Create.Corner(sv, 6)
	local white = Create.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = sv,
	})
	Create.Corner(white, 6)
	Create.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = Create.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Parent = sv,
	})
	Create.Corner(black, 6)
	Create.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
	local svCursor = Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sv,
	})
	Create.Corner(svCursor, UDim.new(1, 0))
	Create.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = svCursor })

	local hue = Create.new("Frame", {
		Name = "Hue",
		Position = UDim2.fromOffset(10, 142),
		Size = UDim2.new(1, -20, 0, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = body,
	})
	Create.Corner(hue, 7)
	Create.new("UIGradient", { Color = ColorSequence.new(HUE_STOPS), Parent = hue })
	local hueCursor = Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 6, 1, 6),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = hue,
	})
	Create.Corner(hueCursor, 3)
	Create.new("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5, Thickness = 1, Parent = hueCursor })

	local hexWrap = Create.new("Frame", {
		Position = UDim2.fromOffset(10, 166),
		Size = UDim2.new(1, -20, 0, 28),
		Parent = body,
	})
	theme:Bind(hexWrap, { BackgroundColor3 = "Control" })
	theme:Corner(hexWrap, "Control")
	local hex = Create.new("TextBox", {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = "",
		Parent = hexWrap,
	})
	theme:Bind(hex, { TextColor3 = "Text" })
	self:_style(hex, "Medium", "Body")

	self._picker = { SVBase = sv, SVCursor = svCursor, HueCursor = hueCursor, Hex = hex }

	Pointer.bind(sv, {
		OnMove = function(position)
			local size = sv.AbsoluteSize
			local s = math.clamp((position.X - sv.AbsolutePosition.X) / math.max(size.X, 1), 0, 1)
			local v = 1 - math.clamp((position.Y - sv.AbsolutePosition.Y) / math.max(size.Y, 1), 0, 1)
			self:_update(self._h, s, v, false, true)
		end,
		OnEnd = function()
			self:_flush()
		end,
	}, popup.Maid)
	Pointer.bind(hue, {
		OnMove = function(position)
			local h = math.clamp((position.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1)
			self:_update(h, self._s, self._v, false, true)
		end,
		OnEnd = function()
			self:_flush()
		end,
	}, popup.Maid)
	popup.Maid:Give(hex.FocusLost:Connect(function()
		local digits = string.match(hex.Text, "(%x%x%x%x%x%x)")
		if digits then
			self:Set(Color3.fromHex(digits))
		end
		self:_syncPicker()
	end))

	self:_syncPicker()
end

function ColorPicker:Destroy()
	if self._popup then
		self._popup.Close()
	end
	Control.Destroy(self)
end

return ColorPicker
