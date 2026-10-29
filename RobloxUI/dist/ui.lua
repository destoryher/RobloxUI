local __defs, __loaded = {}, {}
local function require(name)
	local cached = __loaded[name]
	if cached == nil then
		local define = __defs[name]
		if not define then
			error("[UI] missing module " .. tostring(name), 2)
		end
		cached = define()
		__loaded[name] = cached
	end
	return cached
end

__defs["components/button"] = function()
local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Tween = require("util/tween")

local Button = setmetatable({}, { __index = Control })
Button.__index = Button

local STYLES = { Default = true, Accent = true, Danger = true }

function Button.new(card, cfg)
	Validate.check("CreateButton", cfg, {
		Name = "string!",
		Callback = "function",
		Description = "string",
		Style = "string",
		Disabled = "boolean",
		Confirm = "boolean|table",
	})
	local style = cfg.Style or "Default"
	if not STYLES[style] then
		error(("[UI] CreateButton: Style must be Default, Accent or Danger (got '%s')"):format(style), 0)
	end

	local self = Control.base(card, cfg, "Button", Button)
	local theme = self._ctx.Theme
	self._hover, self._down = false, false

	local button = Create.new("TextButton", {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		Text = self._name,
		BackgroundTransparency = 0,
		Parent = self.Header,
	})
	theme:Corner(button, "Control")
	Create.Padding(button, 12, 0, 12, 0)
	local stroke = theme:Stroke(button, "Stroke", 1)
	theme:Bind(button, {
		Font = function(t)
			return t.Font.Medium
		end,
		TextSize = function(t)
			return t.TextSize.Body
		end,
	})
	self._nameLabel = button
	-- long button text wraps onto a second line instead of spilling past the edges
	self:_fitHeader(button, 0, { padX = 24 })

	self._maid:Give(button.MouseEnter:Connect(function()
		self._hover = true
		self:_rerender(true)
	end))
	self._maid:Give(button.MouseLeave:Connect(function()
		self._hover, self._down = false, false
		self:_rerender(true)
	end))
	self._maid:Give(button.MouseButton1Down:Connect(function()
		self._down = true
		self:_rerender(true)
	end))
	self._maid:Give(button.MouseButton1Up:Connect(function()
		self._down = false
		self:_rerender(true)
	end))
	self._maid:Give(button.Activated:Connect(function()
		if self._disabled then
			return
		end
		if cfg.Confirm then
			local opts = type(cfg.Confirm) == "table" and cfg.Confirm or {}
			self._ctx.Window:Confirm({
				Title = opts.Title or "Are you sure?",
				Content = opts.Content or ("Run \"" .. self._name .. "\"?"),
				ConfirmText = opts.ConfirmText,
				CancelText = opts.CancelText,
				Danger = opts.Danger ~= nil and opts.Danger or style == "Danger",
				OnConfirm = function()
					self:_fire()
				end,
			})
		else
			self:_fire()
		end
	end))

	self:_onRender(function(t, animate)
		local c = t.Colors
		local bg, text
		if style == "Accent" then
			bg = c.Accent
			text = c.AccentText
		else
			bg = self._down and c.ControlPressed or (self._hover and c.ControlHover or c.Control)
			text = style == "Danger" and c.Danger or c.Text
		end
		local bgTransparency = 0
		if style == "Accent" then
			bgTransparency = self._down and 0.2 or (self._hover and 0.1 or 0)
		end
		if self._disabled then
			text = c.TextMuted
			bgTransparency = 0.4
		end
		button.TextColor3 = text
		stroke.Color = style == "Accent" and c.Accent or c.Stroke
		if animate then
			Tween.play(button, { BackgroundColor3 = bg, BackgroundTransparency = bgTransparency }, t.Animation.Fast)
		else
			button.BackgroundColor3 = bg
			button.BackgroundTransparency = bgTransparency
		end
	end)

	return self:_finish(cfg)
end

function Button:Fire()
	if not self._disabled then
		self:_fire()
	end
end

return Button
end

__defs["components/chips"] = function()
local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Tween = require("util/tween")

local Chips = setmetatable({}, { __index = Control })
Chips.__index = Chips

local function toList(options)
	local list, seen = {}, {}
	for _, option in ipairs(options) do
		local text = tostring(option)
		if not seen[text] then
			seen[text] = true
			list[#list + 1] = text
		end
	end
	return list
end

local function sameSet(a, b)
	for key in pairs(a) do
		if not b[key] then
			return false
		end
	end
	for key in pairs(b) do
		if not a[key] then
			return false
		end
	end
	return true
end

function Chips.new(card, cfg)
	Validate.check("CreateChips", cfg, {
		Name = "string",
		Options = "table!",
		Multi = "boolean",
		Default = "string|number|table",
		Description = "string",
		Callback = "function",
		Disabled = "boolean",
		FireDefault = "boolean",
	})
	local self = Control.base(card, cfg, "Chips", Chips)
	local ctx = self._ctx
	self._multi = cfg.Multi == true
	self._options = toList(cfg.Options)
	self._selected = {}
	self._refs = {}

	if cfg.Name then
		self:_compactHeader()
		self:_addName(0)
	else
		self.Header.Size = UDim2.new(1, 0, 0, 0)
		self.Header.Visible = false
	end

	local field = Create.new("Frame", {
		Name = "Field",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = self.Row,
	})
	local list = Create.List(field, Enum.FillDirection.Horizontal, 6)
	list.Wraps = true
	self._field = field

	self:_applyValue(cfg.Default)
	self:_build()
	self:_onRender(function(t, animate)
		self:_paint(t, animate)
	end)

	if cfg.FireDefault then
		self:_fire(self:Get())
	end
	return self:_finish(cfg)
end

function Chips:_build()
	for _, child in ipairs(self._field:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self._refs = {}
	local height = self._ctx.Touch and 34 or 28
	for index, option in ipairs(self._options) do
		local chip = Create.new("TextButton", {
			Name = option,
			Size = UDim2.new(0, 0, 0, height),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = option,
			BackgroundTransparency = 0,
			LayoutOrder = index,
			Parent = self._field,
		})
		Create.Padding(chip, 12, 0, 12, 0)
		Create.Corner(chip, UDim.new(1, 0))
		local stroke = Create.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1, Parent = chip })
		self:_style(chip, "Medium", "Body")
		local ref = { Button = chip, Stroke = stroke, hover = false }
		self._refs[option] = ref
		chip.Activated:Connect(function()
			if not self._disabled then
				self:_pick(option)
			end
		end)
		chip.MouseEnter:Connect(function()
			ref.hover = true
			self:_rerender(true)
		end)
		chip.MouseLeave:Connect(function()
			ref.hover = false
			self:_rerender(true)
		end)
	end
end

function Chips:_paint(t, animate)
	local c = t.Colors
	for option, ref in pairs(self._refs) do
		local on = self._selected[option] == true
		local bg = on and c.Accent or (ref.hover and c.ControlHover or c.Control)
		local text = on and c.AccentText or (ref.hover and c.Text or c.TextDim)
		ref.Button.TextColor3 = self._disabled and c.TextMuted or text
		ref.Stroke.Color = on and c.Accent or c.Stroke
		ref.Button.BackgroundTransparency = self._disabled and 0.5 or 0
		if animate then
			Tween.play(ref.Button, { BackgroundColor3 = bg }, t.Animation.Fast)
		else
			ref.Button.BackgroundColor3 = bg
		end
	end
end

function Chips:_selectedList()
	local out = {}
	for _, option in ipairs(self._options) do
		if self._selected[option] then
			out[#out + 1] = option
		end
	end
	return out
end

function Chips:_applyValue(value)
	local wanted = {}
	if type(value) == "table" then
		for _, entry in ipairs(value) do
			wanted[tostring(entry)] = true
		end
	elseif value ~= nil then
		wanted[tostring(value)] = true
	end
	local valid, count = {}, 0
	for _, option in ipairs(self._options) do
		if wanted[option] and (self._multi or count == 0) then
			valid[option] = true
			count = count + 1
		end
	end
	local changed = not sameSet(valid, self._selected)
	self._selected = valid
	return changed
end

function Chips:Get()
	local list = self:_selectedList()
	if self._multi then
		return list
	end
	return list[1]
end

function Chips:Set(value, silent)
	if self:_applyValue(value) then
		self:_rerender(true)
		if not silent then
			self:_fire(self:Get())
		end
	end
end

function Chips:Clear(silent)
	self:Set(nil, silent)
end

function Chips:SelectAll(silent)
	if self._multi then
		self:Set(self._options, silent)
	end
end

function Chips:SetOptions(options, silent)
	if type(options) ~= "table" then
		error("[UI] Chips:SetOptions expects a table of options", 0)
	end
	local keep = {}
	for option in pairs(self._selected) do
		keep[#keep + 1] = option
	end
	self._options = toList(options)
	local changed = self:_applyValue(keep)
	self:_build()
	self:_rerender(false)
	if changed and not silent then
		self:_fire(self:Get())
	end
end

function Chips:_pick(option)
	if self._multi then
		local out, found = {}, false
		for _, existing in ipairs(self:_selectedList()) do
			if existing == option then
				found = true
			else
				out[#out + 1] = existing
			end
		end
		if not found then
			out[#out + 1] = option
		end
		self:Set(out)
	else
		self:Set(option)
	end
end

return Chips
end

__defs["components/colorpicker"] = function()
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
end

__defs["components/divider"] = function()
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
end

__defs["components/dropdown"] = function()
local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Tween = require("util/tween")
local Popup = require("core/popup")

local Dropdown = setmetatable({}, { __index = Control })
Dropdown.__index = Dropdown

local function toList(options)
	local list, seen = {}, {}
	for _, option in ipairs(options) do
		local text = tostring(option)
		if not seen[text] then
			seen[text] = true
			list[#list + 1] = text
		end
	end
	return list
end

local function sameSet(a, b)
	for key in pairs(a) do
		if not b[key] then
			return false
		end
	end
	for key in pairs(b) do
		if not a[key] then
			return false
		end
	end
	return true
end

function Dropdown.new(card, cfg)
	Validate.check("CreateDropdown", cfg, {
		Name = "string!",
		Options = "table!",
		Multi = "boolean",
		Default = "string|number|table",
		Placeholder = "string",
		Search = "boolean",
		Description = "string",
		Callback = "function",
		Disabled = "boolean",
		FireDefault = "boolean",
	})
	local self = Control.base(card, cfg, "Dropdown", Dropdown)
	local ctx = self._ctx
	local theme = ctx.Theme
	self._multi = cfg.Multi == true
	self._options = toList(cfg.Options)
	self._selected = {}
	self._placeholder = cfg.Placeholder or (self._multi and "None" or "Select...")
	self._searchable = cfg.Search
	self._hover, self._open = false, false

	self:_compactHeader()
	self:_addName(0)

	local field = self:_addField(ctx.RowHeight)
	local button = Create.new("TextButton", {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		Parent = field,
	})
	theme:Corner(button, "Control")
	local stroke = theme:Stroke(button, "Stroke", 1)
	local summary = Create.new("TextLabel", {
		Name = "Summary",
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -38, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})
	self:_style(summary, "Medium", "Body")
	local chevron = Create.new("TextLabel", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Text = "\u{203A}",
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = 90,
		Parent = button,
	})
	self:_style(chevron, "Bold", "Title")
	self._button = button

	self._maid:Give(button.MouseEnter:Connect(function()
		self._hover = true
		self:_rerender(true)
	end))
	self._maid:Give(button.MouseLeave:Connect(function()
		self._hover = false
		self:_rerender(true)
	end))
	self._maid:Give(button.Activated:Connect(function()
		if self._open then
			self._popup.Close()
		else
			self:_openPopup()
		end
	end))

	self:_applyValue(cfg.Default)
	self:_onRender(function(t, animate)
		local c = t.Colors
		local text, empty = self:_summaryText()
		summary.Text = text
		summary.TextColor3 = (empty or self._disabled) and c.TextMuted or c.Text
		chevron.TextColor3 = c.TextDim
		stroke.Color = self._open and c.Accent or c.Stroke
		button.BackgroundTransparency = self._disabled and 0.4 or 0
		local bg = (self._hover or self._open) and c.ControlHover or c.Control
		local rotation = self._open and -90 or 90
		if animate then
			Tween.play(button, { BackgroundColor3 = bg }, t.Animation.Fast)
			Tween.play(chevron, { Rotation = rotation }, t.Animation.Fast)
		else
			button.BackgroundColor3 = bg
			chevron.Rotation = rotation
		end
	end)

	if cfg.FireDefault then
		self:_fire(self:Get())
	end
	return self:_finish(cfg)
end

function Dropdown:_selectedList()
	local out = {}
	for _, option in ipairs(self._options) do
		if self._selected[option] then
			out[#out + 1] = option
		end
	end
	return out
end

function Dropdown:_summaryText()
	local list = self:_selectedList()
	if #list == 0 then
		return self._placeholder, true
	end
	if #list > 3 then
		return #list .. " selected", false
	end
	return table.concat(list, ", "), false
end

function Dropdown:_applyValue(value)
	local wanted = {}
	if type(value) == "table" then
		for _, entry in ipairs(value) do
			wanted[tostring(entry)] = true
		end
	elseif value ~= nil then
		wanted[tostring(value)] = true
	end
	local valid, count = {}, 0
	for _, option in ipairs(self._options) do
		if wanted[option] and (self._multi or count == 0) then
			valid[option] = true
			count = count + 1
		end
	end
	local changed = not sameSet(valid, self._selected)
	self._selected = valid
	return changed
end

function Dropdown:_refresh()
	self:_rerender(true)
	self:_paintRows()
end

function Dropdown:Get()
	local list = self:_selectedList()
	if self._multi then
		return list
	end
	return list[1]
end

function Dropdown:Set(value, silent)
	if self:_applyValue(value) then
		self:_refresh()
		if not silent then
			self:_fire(self:Get())
		end
	end
end

function Dropdown:Clear(silent)
	self:Set(nil, silent)
end

function Dropdown:SelectAll(silent)
	if self._multi then
		self:Set(self._options, silent)
	end
end

function Dropdown:SetOptions(options, silent)
	if type(options) ~= "table" then
		error("[UI] Dropdown:SetOptions expects a table of options", 0)
	end
	local keep = {}
	for option in pairs(self._selected) do
		keep[#keep + 1] = option
	end
	self._options = toList(options)
	local changed = self:_applyValue(keep)
	self:_rerender(true)
	if self._list then
		self:_buildRows()
	end
	if changed and not silent then
		self:_fire(self:Get())
	end
end

function Dropdown:_pick(option)
	if self._multi then
		local out, found = {}, false
		for _, existing in ipairs(self:_selectedList()) do
			if existing == option then
				found = true
			else
				out[#out + 1] = existing
			end
		end
		if not found then
			out[#out + 1] = option
		end
		self:Set(out)
	else
		self:Set(option)
		if self._popup then
			self._popup.Close()
		end
	end
end

function Dropdown:_paintRows()
	if not self._rowRefs then
		return
	end
	local c = self._ctx.Theme:Get().Colors
	for option, ref in pairs(self._rowRefs) do
		local on = self._selected[option] == true
		ref.Label.TextColor3 = on and c.Accent or c.Text
		if self._multi then
			ref.Row.BackgroundColor3 = c.ControlHover
			ref.Row.BackgroundTransparency = ref.hover and 0.5 or 1
			ref.Box.BackgroundColor3 = on and c.Accent or c.Control
			ref.Stroke.Color = on and c.Accent or c.TextMuted
			ref.Inner.Visible = on
			ref.Inner.BackgroundColor3 = c.AccentText
		else
			ref.Row.BackgroundColor3 = on and c.Control or c.ControlHover
			ref.Row.BackgroundTransparency = on and 0 or (ref.hover and 0.5 or 1)
		end
	end
end

function Dropdown:_filterRows(text)
	local query = string.lower(string.match(text or "", "^%s*(.-)%s*$"))
	self._query = query
	for option, ref in pairs(self._rowRefs or {}) do
		ref.Row.Visible = query == "" or string.find(string.lower(option), query, 1, true) ~= nil
	end
end

function Dropdown:_makeRow(index, option)
	local ctx = self._ctx
	local theme = ctx.Theme
	local rowH = ctx.Touch and 40 or 30
	local row = Create.new("TextButton", {
		Name = option,
		Size = UDim2.new(1, 0, 0, rowH),
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Parent = self._list,
	})
	theme:Corner(row, "Control")
	local label = Create.new("TextLabel", {
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, self._multi and -42 or -20, 1, 0),
		Text = option,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	self:_style(label, "Medium", "Body")
	local ref = { Row = row, Label = label, hover = false }
	if self._multi then
		local box = Create.new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			Parent = row,
		})
		Create.Corner(box, 5)
		ref.Stroke = Create.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1, Parent = box })
		ref.Inner = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(8, 8),
			Parent = box,
		})
		Create.Corner(ref.Inner, 2)
		ref.Box = box
	end
	if self._query and self._query ~= "" and not string.find(string.lower(option), self._query, 1, true) then
		row.Visible = false
	end
	row.Activated:Connect(function()
		self:_pick(option)
	end)
	row.MouseEnter:Connect(function()
		ref.hover = true
		self:_paintRows()
	end)
	row.MouseLeave:Connect(function()
		ref.hover = false
		self:_paintRows()
	end)
	self._rowRefs[option] = ref
end

local ROW_CHUNK = 40

function Dropdown:_buildRows()
	local ctx = self._ctx
	local theme = ctx.Theme
	local list = self._list
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self._rowRefs = {}
	self._buildToken = (self._buildToken or 0) + 1
	local token = self._buildToken
	local options = self._options
	local count = #options

	if count == 0 then
		local empty = Create.new("TextLabel", {
			Size = UDim2.new(1, 0, 0, ctx.Touch and 40 or 30),
			Text = "No options",
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = list,
		})
		theme:Text(empty, "TextMuted", "Regular", "Body")
		return
	end

	for index = 1, math.min(ROW_CHUNK, count) do
		self:_makeRow(index, options[index])
	end
	self:_paintRows()

	if count > ROW_CHUNK then
		task.spawn(function()
			local nextIndex = ROW_CHUNK + 1
			while nextIndex <= count do
				task.wait()
				if self._buildToken ~= token or not self._list or not self._list.Parent then
					return
				end
				for index = nextIndex, math.min(nextIndex + ROW_CHUNK - 1, count) do
					self:_makeRow(index, options[index])
				end
				nextIndex = nextIndex + ROW_CHUNK
				self:_paintRows()
			end
		end)
	end
end

function Dropdown:_openPopup()
	if self._disabled or self._open then
		return
	end
	local ctx = self._ctx
	local theme = ctx.Theme
	local rowH = ctx.Touch and 40 or 30
	local count = #self._options
	local showSearch = self._searchable
	if showSearch == nil then
		showSearch = count > 8
	end
	local headerH = showSearch and 42 or 0
	local footerH = self._multi and 46 or 0
	local listH = math.min(math.max(count, 1) * (rowH + 2) + 10, 230)

	local popup = Popup.open(ctx.Window, self._button, {
		Height = headerH + listH + footerH,
		OnClose = function()
			self._open = false
			self._buildToken = (self._buildToken or 0) + 1
			self._popup, self._list, self._rowRefs = nil, nil, nil
			self:_rerender(true)
		end,
	})
	self._popup, self._open = popup, true
	self._query = ""

	local body = popup.Body
	if showSearch then
		local box = Create.new("TextBox", {
			Name = "Search",
			Position = UDim2.new(0, 8, 0, 7),
			Size = UDim2.new(1, -16, 0, headerH - 14),
			BackgroundTransparency = 0,
			Text = "",
			PlaceholderText = "Search...",
			Parent = body,
		})
		theme:Bind(box, { BackgroundColor3 = "Control", TextColor3 = "Text", PlaceholderColor3 = "TextMuted" })
		self:_style(box, "Regular", "Body")
		theme:Corner(box, "Control")
		Create.Padding(box, 10, 0, 10, 0)
		popup.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
			self:_filterRows(box.Text)
		end))
	end

	local list = Create.new("ScrollingFrame", {
		Name = "Options",
		Position = UDim2.new(0, 0, 0, headerH),
		Size = UDim2.new(1, 0, 0, listH),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = body,
	})
	theme:Bind(list, { ScrollBarImageColor3 = "TextMuted" })
	Create.Padding(list, 6, 4, 6, 4)
	Create.List(list, Enum.FillDirection.Vertical, 2)
	self._list = list
	self:_buildRows()
	popup.Maid:Give(theme:Watch(function()
		self:_paintRows()
	end))

	if self._multi then
		local footer = Create.new("Frame", {
			Name = "Footer",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, footerH),
			Parent = body,
		})
		local line = Create.new("Frame", { Size = UDim2.new(1, 0, 0, 1), Parent = footer })
		theme:Bind(line, { BackgroundColor3 = "Divider" })
		local function small(text, x, action)
			local button = Create.new("TextButton", {
				Name = text,
				Position = UDim2.new(x, x == 0 and 8 or 4, 0, 8),
				Size = UDim2.new(0.5, -12, 1, -16),
				Text = text,
				BackgroundTransparency = 0,
				Parent = footer,
			})
			theme:Bind(button, { BackgroundColor3 = "Control", TextColor3 = "Text" })
			self:_style(button, "Medium", "Small")
			theme:Corner(button, "Control")
			button.Activated:Connect(action)
		end
		small("Select all", 0, function()
			self:SelectAll()
		end)
		small("Clear", 0.5, function()
			self:Clear()
		end)
	end
end

function Dropdown:Destroy()
	if self._popup then
		self._popup.Close()
	end
	Control.Destroy(self)
end

return Dropdown
end

__defs["components/input"] = function()
local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")

local Input = setmetatable({}, { __index = Control })
Input.__index = Input

function Input.new(card, cfg)
	Validate.check("CreateInput", cfg, {
		Name = "string!",
		Default = "string|number",
		Placeholder = "string",
		Numeric = "boolean",
		Description = "string",
		Callback = "function",
		Disabled = "boolean",
		FireDefault = "boolean",
	})
	local self = Control.base(card, cfg, "Input", Input)
	local ctx = self._ctx
	local theme = ctx.Theme
	self._numeric = cfg.Numeric == true
	self._text = cfg.Default ~= nil and tostring(cfg.Default) or ""

	self:_compactHeader()
	self:_addName(0)

	local field = self:_addField(ctx.RowHeight)
	local wrap = Create.new("Frame", { Name = "Box", Size = UDim2.fromScale(1, 1), Parent = field })
	theme:Corner(wrap, "Control")
	local stroke = theme:Stroke(wrap, "Stroke", 1)
	local box = Create.new("TextBox", {
		Name = "Input",
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = self._text,
		PlaceholderText = cfg.Placeholder or "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClipsDescendants = true,
		Parent = wrap,
	})
	self:_style(box, "Medium", "Body")
	theme:Bind(box, { PlaceholderColor3 = "TextMuted" })
	self._box = box

	self._maid:Give(box.Focused:Connect(function()
		self._focused = true
		self:_rerender(true)
	end))
	self._maid:Give(box.FocusLost:Connect(function(enterPressed)
		self._focused = false
		self:_commit(box.Text, enterPressed)
		self:_rerender(true)
	end))

	self:_onRender(function(t)
		local c = t.Colors
		wrap.BackgroundColor3 = self._focused and c.ControlHover or c.Control
		wrap.BackgroundTransparency = self._disabled and 0.4 or 0
		stroke.Color = self._focused and c.Accent or c.Stroke
		box.TextColor3 = self._disabled and c.TextMuted or c.Text
		box.TextEditable = not self._disabled
	end)

	if cfg.FireDefault then
		self:_fire(self:Get(), false)
	end
	return self:_finish(cfg)
end

function Input:_commit(text, enterPressed)
	text = string.match(text, "^%s*(.-)%s*$")
	if self._numeric and text ~= "" and tonumber(text) == nil then
		self._box.Text = self._text
		return
	end
	self._box.Text = text
	if text ~= self._text then
		self._text = text
		self:_fire(self:Get(), enterPressed)
	end
end

function Input:Get()
	if self._numeric then
		return tonumber(self._text)
	end
	return self._text
end

function Input:Set(value, silent)
	local text = value == nil and "" or tostring(value)
	if self._numeric and text ~= "" and tonumber(text) == nil then
		error("[UI] Input:Set expects a number for a numeric input", 0)
	end
	self._box.Text = text
	if text ~= self._text then
		self._text = text
		if not silent then
			self:_fire(self:Get(), false)
		end
	end
end

function Input:SetPlaceholder(text)
	self._box.PlaceholderText = tostring(text)
end

return Input
end

__defs["components/keybind"] = function()
local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Services = require("util/services")

local UserInputService = Services.UserInputService

local Keybind = setmetatable({}, { __index = Control })
Keybind.__index = Keybind

local function toKey(value)
	if value == nil then
		return nil
	end
	if typeof(value) == "EnumItem" then
		return value
	end
	if type(value) == "string" and Enum.KeyCode[value] then
		return Enum.KeyCode[value]
	end
	error("[UI] Keybind: expected an Enum.KeyCode or a key name like \"F\"", 0)
end

function Keybind.new(card, cfg)
	Validate.check("CreateKeybind", cfg, {
		Name = "string!",
		Default = "EnumItem|string",
		Callback = "function",
		Pressed = "function",
		Description = "string",
		Disabled = "boolean",
	})
	local self = Control.base(card, cfg, "Keybind", Keybind)
	local theme = self._ctx.Theme
	self._key = toKey(cfg.Default)
	self._listening = false
	self._pressed = cfg.Pressed
	self:_addName(100)

	local button = Create.new("TextButton", {
		Name = "Key",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(92, self._ctx.Touch and 32 or 26),
		BackgroundTransparency = 0,
		Parent = self.Header,
	})
	theme:Corner(button, "Control")
	local stroke = theme:Stroke(button, "Stroke", 1)
	self:_style(button, "Medium", "Small")

	self._maid:Give(button.Activated:Connect(function()
		if self._disabled then
			return
		end
		self._listening = not self._listening
		self:_rerender(true)
	end))

	self._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if self._listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				self._listening = false
				if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
					self:Set(nil)
				elseif input.KeyCode ~= Enum.KeyCode.Escape then
					self:Set(input.KeyCode)
				end
				self:_rerender(true)
			end
			return
		end
		if processed or self._disabled or not self._key or not self._pressed then
			return
		end
		if input.KeyCode == self._key then
			task.spawn(function()
				local ok, err = pcall(self._pressed)
				if not ok then
					warn(("[UI] Pressed callback for '%s' errored: %s"):format(self._name, tostring(err)))
				end
			end)
		end
	end))

	self:_onRender(function(t)
		local c = t.Colors
		button.BackgroundColor3 = self._listening and c.ControlHover or c.Control
		button.BackgroundTransparency = self._disabled and 0.4 or 0
		button.TextColor3 = self._listening and c.Accent or (self._key and c.Text or c.TextMuted)
		button.Text = self._listening and "..." or (self._key and self._key.Name or "None")
		stroke.Color = self._listening and c.Accent or c.Stroke
	end)

	return self:_finish(cfg)
end

function Keybind:Get()
	return self._key
end

function Keybind:Set(key, silent)
	key = toKey(key)
	if key == self._key then
		return
	end
	self._key = key
	self:_rerender(true)
	self:_emit(key)
	if not silent then
		self:_fire(key)
	end
end

return Keybind
end

__defs["components/label"] = function()
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
end

__defs["components/paragraph"] = function()
local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")

local Paragraph = setmetatable({}, { __index = Control })
Paragraph.__index = Paragraph

function Paragraph.new(card, cfg)
	Validate.check("CreateParagraph", cfg, { Title = "string", Content = "string!" })
	cfg.Name = cfg.Title or cfg.Content
	local self = Control.base(card, cfg, "Paragraph", Paragraph)
	local theme = self._ctx.Theme
	self.Header.AutomaticSize = Enum.AutomaticSize.Y
	self.Header.Size = UDim2.new(1, 0, 0, 0)

	local panel = Create.new("Frame", {
		Name = "Panel",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.Header,
	})
	theme:Bind(panel, { BackgroundColor3 = "Control" })
	theme:Corner(panel, "Control")
	Create.Padding(panel, 10, 8, 10, 8)
	Create.List(panel, Enum.FillDirection.Vertical, 3)

	local title = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = cfg.Title or "",
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = cfg.Title ~= nil,
		LayoutOrder = 1,
		Parent = panel,
	})
	theme:Text(title, "Text", "Bold", "Body")
	local content = Create.new("TextLabel", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = cfg.Content,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Parent = panel,
	})
	theme:Text(content, "TextDim", "Regular", "Small")
	self._title, self._content = title, content
	return self
end

function Paragraph:SetTitle(text)
	self._title.Text = tostring(text)
	self._title.Visible = text ~= nil and text ~= ""
	self._name = tostring(text)
end

function Paragraph:SetContent(text)
	self._content.Text = tostring(text)
end

function Paragraph:Set(text)
	self:SetContent(text)
end

function Paragraph:Get()
	return self._content.Text
end

return Paragraph
end

__defs["components/progress"] = function()
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
end

__defs["components/slider"] = function()
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
end

__defs["components/stat"] = function()
local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Fit = require("util/fit")

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

	-- The value takes the width it needs (up to 60% of the row); the name gets the rest and wraps if it must.
	self:_addName(function(width)
		local needed = value.Text == "" and 0 or Fit.width(value.Text, value.TextSize, value.Font) + 2
		local valueW = math.min(needed, math.floor(width * 0.6))
		value.Size = UDim2.new(0, valueW, 1, 0)
		return valueW > 0 and valueW + 12 or 0
	end, { watch = { value } })

	self:_onRender(function(t)
		local c = t.Colors
		self._nameLabel.TextColor3 = self._disabled and c.TextMuted or c.TextDim
		value.TextColor3 = self._disabled and c.TextMuted or c[STYLES[self._style_]]
	end)
	return self:_finish(cfg)
end

function Stat:Get()
	return self._value.Text
end

function Stat:Set(value)
	local text = tostring(value)
	if self._value.Text ~= text then
		self._value.Text = text
	end
end

function Stat:SetStyle(style)
	if not STYLES[style] then
		error(("[UI] Stat:SetStyle: Style must be Normal, Accent, Success or Danger (got '%s')"):format(tostring(style)), 0)
	end
	self._style_ = style
	self:_rerender(false)
end

return Stat
end

__defs["components/toggle"] = function()
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
	self:_emit(value)
	if not silent then
		self:_fire(value)
	end
end

return Toggle
end

__defs["core/card"] = function()
local Create = require("util/create")
local Maid = require("util/maid")
local Tween = require("util/tween")
local Validate = require("util/validate")
local Fit = require("util/fit")
local Icons = require("core/icons")
local Toggle = require("components/toggle")
local Button = require("components/button")
local Label = require("components/label")
local Dropdown = require("components/dropdown")
local Slider = require("components/slider")
local Input = require("components/input")
local Keybind = require("components/keybind")
local ColorPicker = require("components/colorpicker")
local Paragraph = require("components/paragraph")
local Divider = require("components/divider")
local Progress = require("components/progress")
local Stat = require("components/stat")
local Chips = require("components/chips")

local Card = {}
Card.__index = Card

function Card.new(tab, cfg, column)
	Validate.check("CreateCard", cfg, {
		Name = "string!",
		Icon = "string|number",
		Collapsed = "boolean",
		Column = "number",
		Highlight = "boolean",
	})
	local window = tab.Window
	local theme = window.Theme
	local th = theme:Get()
	local sp = th.Spacing

	local self = setmetatable({}, Card)
	self._ctx = window._ctx
	self._tab = tab
	self._name = cfg.Name
	self._controls = {}
	self._orderCounter = 0
	self._collapsed = cfg.Collapsed == true
	self._animating = false
	self._token = 0
	self._maid = tab._maid:Give(Maid.new())

	local frame = Create.new("Frame", {
		Name = "Card",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = column,
	})
	local highlight = cfg.Highlight == true
	theme:Bind(frame, {
		BackgroundColor3 = function(t)
			return highlight and Color3.new(1, 1, 1) or t.Colors.Card
		end,
		BackgroundTransparency = function(t)
			return t.Transparency.Card
		end,
	})
	local sheen = Create.new("UIGradient", { Rotation = highlight and 25 or 90, Parent = frame })
	theme:Bind(sheen, {
		Color = function(t)
			if highlight then
				return ColorSequence.new(t.Colors.Card:Lerp(t.Colors.Accent, 0.16), t.Colors.Card:Lerp(t.Colors.AccentAlt, 0.08))
			end
			return ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.88, 0.88, 0.88))
		end,
	})
	theme:Corner(frame, "Card")
	local cardStroke = theme:Stroke(frame, highlight and "Accent" or "Stroke", 1)
	if highlight then
		cardStroke.Transparency = 0.45
	end
	Create.List(frame, Enum.FillDirection.Vertical, 0)
	self.Frame = frame
	self._maid:Give(frame)

	local header = Create.new("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, sp.Header),
		LayoutOrder = 1,
		Parent = frame,
	})
	local titleX = 14
	if cfg.Icon ~= nil then
		local badge = Create.new("Frame", {
			Name = "IconBadge",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			Parent = header,
		})
		theme:Bind(badge, { BackgroundColor3 = "Control" })
		Create.Corner(badge, 7)
		local icon = Icons.Make(badge, cfg.Icon, cfg.Name, 18)
		icon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Frame.Position = UDim2.fromScale(0.5, 0.5)
		self._maid:Give(theme:Watch(function(t)
			icon:Paint(t.Colors.Accent, true)
		end))
		titleX = 48
	end
	local title = Create.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, titleX, 0, 0),
		Size = UDim2.new(1, -(titleX + 40), 1, 0),
		Text = cfg.Name,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	theme:Text(title, "Text", "Bold", "Header")
	self._title = title
	Fit.bind({
		label = title,
		container = header,
		base = sp.Header,
		reserve = titleX + 40,
		maid = self._maid,
		scale = function()
			return window:_textScale()
		end,
	})

	local chevron = Create.new("TextLabel", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Text = "\u{203A}",
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = self._collapsed and 0 or 90,
		Parent = header,
	})
	theme:Text(chevron, "TextDim", "Bold", "Title")
	self._chevron = chevron

	local dividerWrap = Create.new("Frame", {
		Name = "Divider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 2,
		Parent = frame,
	})
	Create.Padding(dividerWrap, 10, 0, 10, 0)
	local divider = Create.new("Frame", { Size = UDim2.fromScale(1, 1), Parent = dividerWrap })
	theme:Bind(divider, { BackgroundColor3 = "Divider" })

	local clip = Create.new("Frame", {
		Name = "Clip",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = self._collapsed and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = frame,
	})
	local body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = clip,
	})
	local list = Create.List(body, Enum.FillDirection.Vertical, 6)
	Create.Padding(body, 10, 8, 10, 10)
	self.Body, self._clip, self._list = body, clip, list

	self._maid:Give(header.Activated:Connect(function()
		self:SetCollapsed(not self._collapsed)
	end))
	return self
end

function Card:_nextOrder()
	self._orderCounter = self._orderCounter + 1
	return self._orderCounter
end

function Card:_register(control)
	self._controls[control] = true
end

function Card:_unregister(control)
	self._controls[control] = nil
end

function Card:SetCollapsed(collapsed)
	collapsed = collapsed and true or false
	if collapsed == self._collapsed then
		return
	end
	self._collapsed = collapsed
	self._token = self._token + 1
	local token = self._token
	local th = self._ctx.Theme:Get()
	local clip = self._clip

	local window = self._ctx.Window
	local scale = window._uiScale * window._scale.Scale
	local height = self.Body.AbsoluteSize.Y / math.max(scale, 0.01)

	Tween.play(self._chevron, { Rotation = collapsed and 0 or 90 }, th.Animation.Normal)
	if collapsed then
		clip.AutomaticSize = Enum.AutomaticSize.None
		clip.Size = UDim2.new(1, 0, 0, height)
		Tween.play(clip, { Size = UDim2.new(1, 0, 0, 0) }, th.Animation.Normal)
	else
		clip.AutomaticSize = Enum.AutomaticSize.None
		local tween = Tween.play(clip, { Size = UDim2.new(1, 0, 0, height) }, th.Animation.Normal)
		tween.Completed:Connect(function()
			if self._token == token and not self._collapsed then
				clip.AutomaticSize = Enum.AutomaticSize.Y
				clip.Size = UDim2.new(1, 0, 0, 0)
			end
		end)
	end
end

function Card:IsCollapsed()
	return self._collapsed
end

function Card:SetName(text)
	self._name = tostring(text)
	self._title.Text = self._name
end

function Card:_applyFilter(query)
	if query == "" then
		for control in pairs(self._controls) do
			control:_setFiltered(false)
		end
		self.Frame.Visible = true
		return 1
	end
	local titleMatch = string.find(string.lower(self._name), query, 1, true) ~= nil
	local count = 0
	for control in pairs(self._controls) do
		local match = titleMatch or control:_matches(query)
		control:_setFiltered(not match)
		if match then
			count = count + 1
		end
	end
	local visible = titleMatch or count > 0
	self.Frame.Visible = visible
	return visible and math.max(count, 1) or 0
end

function Card:CreateToggle(cfg)
	return Toggle.new(self, cfg)
end

function Card:CreateButton(cfg)
	return Button.new(self, cfg)
end

function Card:CreateLabel(cfg)
	return Label.new(self, cfg)
end

function Card:CreateDropdown(cfg)
	return Dropdown.new(self, cfg)
end

function Card:CreateSlider(cfg)
	return Slider.new(self, cfg)
end

function Card:CreateInput(cfg)
	return Input.new(self, cfg)
end

function Card:CreateKeybind(cfg)
	return Keybind.new(self, cfg)
end

function Card:CreateColorPicker(cfg)
	return ColorPicker.new(self, cfg)
end

function Card:CreateParagraph(cfg)
	return Paragraph.new(self, cfg)
end

function Card:CreateProgress(cfg)
	return Progress.new(self, cfg)
end

function Card:CreateStat(cfg)
	return Stat.new(self, cfg)
end

function Card:CreateChips(cfg)
	return Chips.new(self, cfg)
end

function Card:CreateDivider(cfg)
	return Divider.new(self, cfg)
end

function Card:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for control in pairs(self._controls) do
		control:Destroy()
	end
	self._tab:_removeCard(self)
	self._maid:Destroy()
end

return Card
end

__defs["core/control"] = function()
local Create = require("util/create")
local Maid = require("util/maid")
local Fit = require("util/fit")

local Control = {}
Control.__index = Control

function Control.base(card, cfg, kind, class)
	local ctx = card._ctx
	local self = setmetatable({}, class or Control)
	self._ctx = ctx
	self._card = card
	self._kind = kind
	self._name = cfg.Name or cfg.Text or ""
	self._cb = cfg.Callback
	self._disabled = false
	self._visible = true
	self._filtered = false
	self._renderers = {}
	self._maid = Maid.new()

	self.Row = Create.new("Frame", {
		Name = kind,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = card:_nextOrder(),
	})
	Create.List(self.Row, Enum.FillDirection.Vertical, 2)
	self.Header = Create.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ctx.RowHeight),
		LayoutOrder = 1,
		Parent = self.Row,
	})
	self.Row.Parent = card.Body

	self._maid:Give(ctx.Theme:Watch(function()
		self:_rerender(false)
	end))
	card:_register(self)
	return self
end

function Control:_onRender(fn)
	self._renderers[#self._renderers + 1] = fn
	fn(self._ctx.Theme:Get(), false)
end

function Control:_rerender(animate)
	local theme = self._ctx.Theme:Get()
	for _, fn in ipairs(self._renderers) do
		local ok, err = pcall(fn, theme, animate)
		if not ok and not self._warned then
			self._warned = true
			warn(("[UI] render error in %s '%s': %s"):format(self._kind, self._name, tostring(err)))
		end
	end
end

-- Long text wraps onto extra lines and the header grows, instead of being cut off with "...".
-- `reserve` is the space kept free on the right (number, or function(width) -> number).
function Control:_fitHeader(label, reserve, opts)
	opts = opts or {}
	local window = self._ctx.Window
	self._fitter = Fit.bind({
		label = label,
		container = self.Header,
		base = self.Header.Size.Y.Offset,
		reserve = reserve,
		padX = opts.padX,
		sizeLabel = opts.sizeLabel,
		watch = opts.watch,
		maid = self._maid,
		scale = function()
			return window:_textScale()
		end,
	})
	return self._fitter
end

function Control:_addName(reserve, opts)
	local fixed = type(reserve) == "number" and reserve or 0
	local label = Create.new("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -fixed, 1, 0),
		Text = self._name,
		Parent = self.Header,
	})
	self._ctx.Theme:Bind(label, {
		Font = function(theme)
			return theme.Font.Medium
		end,
		TextSize = function(theme)
			return theme.TextSize.Body
		end,
	})
	self._nameLabel = label
	self:_onRender(function(theme)
		label.TextColor3 = self._disabled and theme.Colors.TextMuted or theme.Colors.Text
	end)
	opts = opts or {}
	self:_fitHeader(label, reserve or 0, { sizeLabel = true, watch = opts.watch })
	return label
end

function Control:_fire(...)
	local cb = self._cb
	if not cb then
		return
	end
	local name = self._name
	task.spawn(function(...)
		local ok, err = pcall(cb, ...)
		if not ok then
			warn(("[UI] callback for '%s' errored: %s"):format(name, tostring(err)))
		end
	end, ...)
end

function Control:OnChange(fn)
	local listeners = self._listeners
	if not listeners then
		listeners = {}
		self._listeners = listeners
	end
	local handle = {}
	listeners[handle] = fn
	function handle.Disconnect()
		listeners[handle] = nil
	end
	handle.Destroy = handle.Disconnect
	return handle
end

function Control:_emit(...)
	local listeners = self._listeners
	if not listeners then
		return
	end
	for _, fn in pairs(listeners) do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn(("[UI] OnChange listener for '%s' errored: %s"):format(self._name, tostring(err)))
		end
	end
end

function Control:_finish(cfg)
	if cfg.Description then
		self:SetDescription(cfg.Description)
	end
	if cfg.Disabled then
		self:SetDisabled(true)
	end
	return self
end

function Control:_applyVisibility()
	self.Row.Visible = self._visible and not self._filtered
end

function Control:_setFiltered(filtered)
	self._filtered = filtered
	self:_applyVisibility()
end

function Control:_matches(query)
	local haystack = string.lower(self._name .. " " .. (self._desc or ""))
	return string.find(haystack, query, 1, true) ~= nil
end

function Control:_compactHeader()
	self.Header.Size = UDim2.new(1, 0, 0, self._ctx.Touch and 26 or 22)
end

function Control:_addField(height)
	return Create.new("Frame", {
		Name = "Field",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = 2,
		Parent = self.Row,
	})
end

function Control:_style(label, font, size)
	self._ctx.Theme:Bind(label, {
		Font = function(theme)
			return theme.Font[font]
		end,
		TextSize = function(theme)
			return theme.TextSize[size]
		end,
	})
end

function Control:SetName(text)
	self._name = tostring(text)
	if self._nameLabel then
		self._nameLabel.Text = self._name
	end
end

function Control:GetName()
	return self._name
end

function Control:SetDescription(text)
	self._desc = text
	if text == nil or text == "" then
		if self._descLabel then
			self._descLabel:Destroy()
			self._descLabel = nil
		end
		return
	end
	if not self._descLabel then
		local label = Create.new("TextLabel", {
			Name = "Description",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 10,
			Parent = self.Row,
		})
		Create.Padding(label, 0, 0, 0, 4)
		self._ctx.Theme:Text(label, "TextDim", "Regular", "Small")
		self._descLabel = label
	end
	self._descLabel.Text = tostring(text)
end

function Control:SetDisabled(disabled)
	self._disabled = disabled and true or false
	self:_rerender(true)
end

function Control:IsDisabled()
	return self._disabled
end

function Control:SetVisible(visible)
	self._visible = visible and true or false
	self:_applyVisibility()
end

function Control:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._card:_unregister(self)
	self._maid:Destroy()
	self.Row:Destroy()
end

return Control
end

__defs["core/dialog"] = function()
local Create = require("util/create")
local Tween = require("util/tween")
local Validate = require("util/validate")
local PushButton = require("core/pushbutton")

local Dialog = {}

function Dialog.open(window, cfg)
	Validate.check("Confirm", cfg, {
		Title = "string",
		Content = "string",
		ConfirmText = "string",
		CancelText = "string",
		Danger = "boolean",
		OnConfirm = "function",
		OnCancel = "function",
	})
	if cfg.Title == nil and cfg.Content == nil then
		error("[UI] Confirm: needs a Title or Content", 0)
	end
	window:_closePopup()
	if window._dialog then
		window._dialog.Close(false)
	end

	local theme = window.Theme
	local anim = theme:Get().Animation
	local vp = window:_viewport()
	local closed = false
	local obj = {}

	local dim = Create.new("TextButton", {
		Name = "ConfirmDim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 60,
		Parent = window._overlay,
	})
	local card = Create.new("Frame", {
		Name = "Dialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, math.min(360, vp.X - 32), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Parent = dim,
	})
	theme:Bind(card, { BackgroundColor3 = "Card" })
	theme:Corner(card, "Window")
	theme:Stroke(card, "Stroke", 1)
	local scale = Create.new("UIScale", { Scale = 0.92, Parent = card })
	Create.Padding(card, 18, 18, 18, 16)
	Create.List(card, Enum.FillDirection.Vertical, 8)

	if cfg.Title then
		local title = Create.new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = cfg.Title,
			TextWrapped = true,
			LayoutOrder = 1,
			Parent = card,
		})
		theme:Text(title, "Text", "Bold", "Title")
	end
	if cfg.Content then
		local content = Create.new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = cfg.Content,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
			Parent = card,
		})
		theme:Text(content, "TextDim", "Regular", "Body")
	end
	local row = Create.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, window._ctx.RowHeight),
		LayoutOrder = 3,
		Parent = card,
	})
	local list = Create.List(row, Enum.FillDirection.Horizontal, 8)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	function obj.Close(confirmed)
		if closed then
			return
		end
		closed = true
		if window._dialog == obj then
			window._dialog = nil
		end
		Tween.play(dim, { BackgroundTransparency = 1 }, anim.Fast)
		local tween = Tween.play(scale, { Scale = 0.92 }, anim.Fast)
		tween.Completed:Connect(function()
			dim:Destroy()
		end)
		dim.Active = false
		local callback = confirmed and cfg.OnConfirm or (confirmed == false and cfg.OnCancel or nil)
		if callback then
			task.spawn(function()
				local ok, err = pcall(callback)
				if not ok then
					warn("[UI] Confirm callback errored: " .. tostring(err))
				end
			end)
		end
	end

	local cancel = PushButton.new(window.Theme, row, cfg.CancelText or "Cancel", "Default", 1, UDim2.new(0.5, -4, 1, 0))
	local confirm = PushButton.new(window.Theme, row, cfg.ConfirmText or "Confirm", cfg.Danger and "Danger" or "Accent", 2, UDim2.new(0.5, -4, 1, 0))
	cancel.Activated:Connect(function()
		obj.Close(false)
	end)
	confirm.Activated:Connect(function()
		obj.Close(true)
	end)
	dim.Activated:Connect(function()
		obj.Close(false)
	end)

	window._dialog = obj
	Tween.play(dim, { BackgroundTransparency = 0.45 }, anim.Normal)
	Tween.play(scale, { Scale = 1 }, anim.Normal)
	return obj
end

return Dialog
end

__defs["core/dock"] = function()
local Create = require("util/create")
local Tween = require("util/tween")
local Drag = require("util/drag")
local Icons = require("core/icons")
local Glyphs = require("util/glyphs")

local Dock = {}
Dock.__index = Dock

local BAR_WIDTH = 380

local function actionButton(window, parent, order, glyph, hoverToken, onClick)
	local theme = window.Theme
	local button = Create.new("TextButton", {
		Name = "Action",
		Size = UDim2.fromOffset(34, 32),
		LayoutOrder = order,
		Parent = parent,
	})
	theme:Corner(button, "Control")
	local _, parts = glyph(button)
	local hover = false
	local function paint()
		local c = theme:Get().Colors
		button.BackgroundColor3 = c.ControlHover
		button.BackgroundTransparency = hover and 0.35 or 1
		Glyphs.paint(parts, hover and c[hoverToken] or c.TextMuted)
	end
	window._maid:Give(theme:Watch(paint))
	window._maid:Give(button.MouseEnter:Connect(function()
		hover = true
		paint()
	end))
	window._maid:Give(button.MouseLeave:Connect(function()
		hover = false
		paint()
	end))
	window._maid:Give(button.MouseButton1Down:Connect(function()
		hover = true
		paint()
	end))
	window._maid:Give(button.MouseButton1Up:Connect(function()
		hover = false
		paint()
	end))
	window._maid:Give(button.Activated:Connect(onClick))
	return button
end

local function buildPill(self, window, cfg)
	local theme = window.Theme
	self.Height = window._ctx.Touch and 48 or 44

	local frame = Create.new("Frame", {
		Name = "MinimizedPill",
		Size = UDim2.fromOffset(0, self.Height),
		AutomaticSize = Enum.AutomaticSize.X,
		Active = true,
		Visible = false,
		ZIndex = 20,
		Parent = window._root,
	})
	theme:Bind(frame, {
		BackgroundColor3 = "Window",
		BackgroundTransparency = function(t)
			return t.Transparency.Pill
		end,
	})
	Create.Corner(frame, UDim.new(1, 0))
	local stroke = Create.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 2,
		Color = Color3.new(1, 1, 1),
		Parent = frame,
	})
	local gradient = Create.new("UIGradient", { Parent = stroke })
	theme:Bind(gradient, {
		Color = function(t)
			return ColorSequence.new(t.Colors.Accent, t.Colors.AccentAlt)
		end,
	})
	local list = Create.List(frame, Enum.FillDirection.Horizontal, 0)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	local handle = Create.new("Frame", {
		Name = "Handle",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 46, 1, 0),
		LayoutOrder = 1,
		Parent = frame,
	})
	local _, moveParts = Glyphs.move(handle, 18)
	local divider = Create.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(0, 1, 0.5, 0),
		LayoutOrder = 2,
		Parent = frame,
	})
	theme:Bind(divider, { BackgroundColor3 = "Divider" })

	local content = Create.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Parent = frame,
	})
	local contentList = Create.List(content, Enum.FillDirection.Horizontal, 10)
	contentList.VerticalAlignment = Enum.VerticalAlignment.Center
	Create.Padding(content, 14, 0, 20, 0)
	local icon = Icons.Make(content, cfg.FabIcon or cfg.Icon, cfg.Title, 24, { Tint = false, Corner = 6, Theme = theme })
	icon.Frame.LayoutOrder = 1
	local title = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = cfg.Title,
		LayoutOrder = 2,
		Parent = content,
	})
	theme:Text(title, "Text", "Medium", "Body")

	window._maid:Give(theme:Watch(function(t)
		Glyphs.paint(moveParts, t.Colors.TextMuted)
		icon:Paint(t.Colors.Accent)
	end))

	self.Frame = frame
	self._tapAllowed = function(x)
		return x >= handle.AbsolutePosition.X + handle.AbsoluteSize.X
	end
end

local function buildBar(self, window, cfg)
	local theme = window.Theme
	self.Height = window._ctx.Touch and 46 or 40
	self.BarWidth = BAR_WIDTH

	local frame = Create.new("Frame", {
		Name = "MinimizedBar",
		Size = UDim2.fromOffset(BAR_WIDTH, self.Height),
		Active = true,
		Visible = false,
		ZIndex = 20,
		Parent = window._root,
	})
	theme:Bind(frame, { BackgroundColor3 = "Control" })
	theme:Corner(frame, "Window")
	theme:Stroke(frame, "Stroke", 1)

	local title = Create.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 18, 0, 0),
		Size = UDim2.new(1, -(18 + 116), 1, 0),
		Text = cfg.Title,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	theme:Text(title, "Text", "Medium", "Body")

	local actions = Create.new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(106, 32),
		Parent = frame,
	})
	local list = Create.List(actions, Enum.FillDirection.Horizontal, 2)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	actionButton(window, actions, 1, function(parent)
		return Glyphs.magnifier(parent, 16)
	end, "Text", function()
		window:Restore()
		task.defer(function()
			if window._searchBox and window._searchWrap.Visible then
				window._searchBox:CaptureFocus()
			end
		end)
	end)
	actionButton(window, actions, 2, function(parent)
		return Glyphs.square(parent, 16)
	end, "Text", function()
		window:Restore()
	end)
	actionButton(window, actions, 3, function(parent)
		return Glyphs.cross(parent, 16)
	end, "Danger", function()
		window:Destroy()
	end)

	self.Frame = frame
	self._tapAllowed = function(x)
		return x < actions.AbsolutePosition.X
	end
end

function Dock.new(window, cfg, mode)
	local self = setmetatable({ Window = window, Mode = mode }, Dock)
	if mode == "Bar" then
		buildBar(self, window, cfg)
	else
		buildPill(self, window, cfg)
	end
	self.Scale = Create.new("UIScale", { Scale = 0, Parent = self.Frame })

	local start, tapOk
	Drag.bind(self.Frame, {
		Threshold = 6,
		OnStart = function(input)
			start = self.Pos
			tapOk = self._tapAllowed(input.Position.X)
		end,
		OnDelta = function(delta)
			if start then
				self.Pos = start + delta / window._uiScale
				self:Place()
			end
		end,
		OnEnd = function(moved)
			if not moved and tapOk then
				window:Restore()
			end
		end,
	}, window._maid)

	window._maid:Give(self.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self.Frame.Visible then
			self:Place()
		end
	end))
	return self
end

function Dock:Place()
	local window = self.Window
	local vp = window:_viewport()
	local frame = self.Frame
	local size
	if self.Mode == "Bar" then
		local width = math.min(self.BarWidth, vp.X - 16)
		if frame.Size.X.Offset ~= width then
			frame.Size = UDim2.fromOffset(width, self.Height)
		end
		size = Vector2.new(width, self.Height)
	else
		size = frame.AbsoluteSize / (math.max(window._uiScale, 0.01) * math.max(self.Scale.Scale, 0.1))
		if size.X < 8 then
			size = Vector2.new(180, self.Height)
		end
	end
	local pos = self.Pos or Vector2.new(12, vp.Y * 0.35)
	pos = Vector2.new(
		math.clamp(pos.X, 0, math.max(0, vp.X - size.X)),
		math.clamp(pos.Y, 0, math.max(0, vp.Y - size.Y))
	)
	self.Pos = pos
	frame.Position = UDim2.fromOffset(math.floor(pos.X), math.floor(pos.Y))
end

function Dock:Show()
	if self.Mode == "Bar" then
		self.Pos = self.Window._pos
	end
	self.Frame.Visible = true
	self:Place()
	Tween.play(self.Scale, { Scale = 1 }, self.Window.Theme:Get().Animation.Normal, Enum.EasingStyle.Back)
end

return Dock
end

__defs["core/effects"] = function()
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
end

__defs["core/icons"] = function()
local Create = require("util/create")
local Glyphs = require("util/glyphs")

local Icons = {}
local registry = {}

local DEFAULTS = {
	home = "\u{1F3E0}", main = "\u{1F3E0}", farm = "\u{1F33E}", pets = "\u{1F43E}", pet = "\u{1F43E}",
	shop = "\u{1F6D2}", egg = "\u{1F95A}", eggs = "\u{1F95A}", settings = "\u{2699}\u{FE0F}", config = "\u{2699}\u{FE0F}",
	misc = "\u{1F527}", tools = "\u{1F6E0}\u{FE0F}", visuals = "\u{1F441}\u{FE0F}", esp = "\u{1F441}\u{FE0F}", eye = "\u{1F441}\u{FE0F}",
	webhook = "\u{1F514}", notifications = "\u{1F514}", bell = "\u{1F514}", trophy = "\u{1F3C6}", leaderboard = "\u{1F3C6}",
	star = "\u{2B50}", event = "\u{1F389}", events = "\u{1F389}", fire = "\u{1F525}", gift = "\u{1F381}",
	user = "\u{1F464}", player = "\u{1F464}", combat = "\u{2694}\u{FE0F}", sword = "\u{2694}\u{FE0F}", target = "\u{1F3AF}",
	filter = "\u{1F50E}", filters = "\u{1F50E}", search = "\u{1F50E}", map = "\u{1F5FA}\u{FE0F}", teleport = "\u{1F5FA}\u{FE0F}",
	money = "\u{1F4B0}", cash = "\u{1F4B0}", gem = "\u{1F48E}", rocket = "\u{1F680}", speed = "\u{1F680}",
	lock = "\u{1F512}", info = "\u{2139}\u{FE0F}", list = "\u{1F4CB}", progression = "\u{1F4CB}", code = "\u{1F4BB}",
	heart = "\u{2764}\u{FE0F}", bolt = "\u{26A1}", lightning = "\u{26A1}", palette = "\u{1F3A8}", theme = "\u{1F3A8}",
	appearance = "\u{1F3A8}", keyboard = "\u{2328}\u{FE0F}", keybinds = "\u{2328}\u{FE0F}", save = "\u{1F4BE}", auto = "\u{1F916}",
	robot = "\u{1F916}", flag = "\u{1F3C1}", race = "\u{1F3C1}", clock = "\u{23F1}\u{FE0F}", time = "\u{23F1}\u{FE0F}",
	bug = "\u{1F41B}", chat = "\u{1F4AC}", inventory = "\u{1F392}", backpack = "\u{1F392}", ghost = "\u{1F47B}",
}

function Icons.Register(name, value)
	if type(name) ~= "string" then
		error("[UI] icon name must be a string", 0)
	end
	registry[name:lower()] = value
end

function Icons.Guess(name)
	local key = string.lower(tostring(name))
	if registry[key] ~= nil or DEFAULTS[key] ~= nil then
		return key
	end
	return nil
end

local remoteCache = {}
local remotePending = {}

local function hash(text)
	local value = 5381
	for index = 1, #text do
		value = (value * 33 + string.byte(text, index)) % 4294967296
	end
	return value
end

local function fetchRemote(url)
	if remoteCache[url] ~= nil then
		return remoteCache[url] or nil
	end
	local ok, result = pcall(function()
		local extension = string.match(url, "%.(%a+)[%?#]?[^/]*$")
		extension = (extension == "jpg" or extension == "jpeg" or extension == "webp") and extension or "png"
		local name = "RobloxUI_icon_" .. hash(url) .. "." .. extension
		if not (isfile and isfile(name)) then
			writefile(name, game:HttpGet(url))
		end
		return getcustomasset(name)
	end)
	remoteCache[url] = ok and result or false
	return ok and result or nil
end

local function whenRemote(url, callback)
	local cached = remoteCache[url]
	if cached then
		callback(cached)
		return
	end
	if cached == false then
		return
	end
	local waiting = remotePending[url]
	if waiting then
		waiting[#waiting + 1] = callback
		return
	end
	remotePending[url] = { callback }
	task.spawn(function()
		local asset = fetchRemote(url)
		local callbacks = remotePending[url]
		remotePending[url] = nil
		if asset then
			for _, fn in ipairs(callbacks) do
				pcall(fn, asset)
			end
		end
	end)
end

local function describeValue(value, depth)
	if depth > 2 then
		return nil
	end
	if type(value) == "number" then
		return "image", "rbxassetid://" .. value
	end
	if type(value) ~= "string" or value == "" then
		return nil
	end
	if value:find("^rbxassetid://") or value:find("^rbxasset://") or value:find("^rbxthumb://") then
		return "image", value
	end
	if value:find("^mark:") then
		return "mark", string.sub(value, 6)
	end
	if value:find("^https?://") then
		local cached = remoteCache[value]
		if cached then
			return "image", cached
		end
		if cached == false then
			return nil
		end
		return nil, nil, value
	end
	local key = value:lower()
	if registry[key] ~= nil then
		return describeValue(registry[key], depth + 1)
	end
	if DEFAULTS[key] then
		return "glyph", DEFAULTS[key]
	end
	if value:find("[\128-\255]") then
		return "glyph", value
	end
	return nil
end

function Icons.Describe(icon)
	return describeValue(icon, 0)
end

local function populate(obj, kind, value, fallback, size, opts)
	local frame = obj.Frame
	for _, child in ipairs(frame:GetChildren()) do
		child:Destroy()
	end
	obj.Kind = kind or "letter"
	obj.IsImage = kind == "image"
	local inner

	if kind == "image" then
		local image = Create.new("ImageLabel", { Size = UDim2.fromScale(1, 1), Image = value, Parent = frame })
		if opts.Corner then
			Create.Corner(image, opts.Corner)
		end
		function inner(color)
			if opts.Tint ~= false then
				image.ImageColor3 = color
			end
		end
	elseif kind == "mark" then
		local style = string.upper(string.sub(value, 1, 1)) .. string.lower(string.sub(value, 2))
		Glyphs.mark(frame, style, size, opts.Theme)
		function inner() end
	elseif kind == "glyph" then
		local label = Create.new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = value,
			Font = Enum.Font.Gotham,
			TextSize = math.floor(size * 0.78),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = frame,
		})
		function inner(_color, active)
			label.TextTransparency = (active == false) and 0.45 or 0
		end
	else
		local glyph = Create.new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(string.sub(fallback or "?", 1, 1)),
			Font = Enum.Font.GothamBold,
			TextSize = math.floor(size * 0.62),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = frame,
		})
		function inner(color)
			glyph.TextColor3 = color
		end
	end

	obj._inner = inner
	if obj._color ~= nil then
		inner(obj._color, obj._active)
	end
end

function Icons.Make(parent, icon, fallback, size, opts)
	opts = opts or {}
	local kind, value, pending = describeValue(icon, 0)
	local frame = Create.new("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	local obj = { Frame = frame }
	function obj.Paint(self, color, active)
		self._color, self._active = color, active
		self._inner(color, active)
	end
	populate(obj, kind, value, fallback, size, opts)

	if pending then
		whenRemote(pending, function(asset)
			if frame.Parent then
				populate(obj, "image", asset, fallback, size, opts)
				if opts.OnChange then
					pcall(opts.OnChange, obj)
				end
			end
		end)
	end
	return obj
end

return Icons
end

__defs["core/keygate"] = function()
local Services = require("util/services")
local Create = require("util/create")
local Maid = require("util/maid")
local Tween = require("util/tween")
local Drag = require("util/drag")
local Glyphs = require("util/glyphs")
local Validate = require("util/validate")
local Mount = require("util/mount")
local Env = require("util/env")
local ThemeManager = require("theme/manager")
local Icons = require("core/icons")
local Effects = require("core/effects")
local PushButton = require("core/pushbutton")

local KeyGate = {}
KeyGate.__index = KeyGate

local WIDTH = 380
local HEADER = 66
local STATUS_COLORS = { Info = "TextDim", Error = "Danger", Success = "Success" }

local function trim(text)
	return (string.match(text or "", "^%s*(.-)%s*$"))
end

local function readSaved(file)
	if not (file and isfile and readfile) then
		return nil
	end
	local ok, content = pcall(function()
		if isfile(file) then
			return readfile(file)
		end
		return nil
	end)
	if ok and type(content) == "string" then
		content = trim(content)
		if content ~= "" then
			return content
		end
	end
	return nil
end

local function writeSaved(file, text)
	if file and writefile then
		pcall(writefile, file, text)
	end
end

function KeyGate.new(cfg)
	Validate.check("CreateKeyGate", cfg, {
		Title = "string!",
		Subtitle = "string",
		Icon = "string|number",
		Theme = "string|table",
		Validate = "function",
		Provider = "table",
		Links = "table",
		SaveKey = "boolean",
		FileName = "string",
		Key = "string",
		MaxAttempts = "number",
		Cooldown = "number",
		Timeout = "number",
		OnSuccess = "function",
		OnClose = "function",
		Effects = "string",
	})
	local validate = cfg.Validate or (cfg.Provider and cfg.Provider.Validate)
	if type(validate) ~= "function" then
		error("[UI] CreateKeyGate: provide Validate (a function) or Provider", 0)
	end
	local links = cfg.Links or {}
	for index, link in ipairs(links) do
		Validate.check("CreateKeyGate Links[" .. index .. "]", link, { Name = "string!", Url = "string!" })
	end

	local self = setmetatable({}, KeyGate)
	self._maid = Maid.new()
	self._cfg = cfg
	self._validate = validate
	self._timeout = cfg.Timeout or 20
	self._maxAttempts = cfg.MaxAttempts or 5
	self._cooldown = cfg.Cooldown or 15
	self._fails = 0
	self._waiters = {}
	self._destroyCallbacks = {}
	self._offset = Vector2.new(0, 0)
	self._uiScale = 1
	self._saveEnabled = cfg.SaveKey ~= false
	self._remember = self._saveEnabled
	self._file = cfg.FileName or ((string.gsub(cfg.Title, "[^%w_]", "")) .. "_key.txt")
	self._statusText, self._statusKind = "", "Info"

	local theme = ThemeManager.new(cfg.Theme or "Mono")
	self.Theme = theme
	local input = Services.UserInputService
	local touch = input.TouchEnabled and not input.MouseEnabled

	local gui = Create.new("ScreenGui", {
		Name = "UILibKey",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		Enabled = false,
	})
	Mount.gui(gui)
	self._gui = gui
	self._maid:Give(gui)

	local root = Create.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	self._root = root
	self._rootScale = Create.new("UIScale", { Parent = root })

	local hasRemember = self._saveEnabled
	local itemHeights = { 44, 32, 44 }
	if hasRemember then
		itemHeights[#itemHeights + 1] = 24
	end
	if #links > 0 then
		itemHeights[#itemHeights + 1] = 40
	end
	local bodyHeight = 14 + 16 + 10 * (#itemHeights - 1)
	for _, height in ipairs(itemHeights) do
		bodyHeight = bodyHeight + height
	end
	self._height = HEADER + bodyHeight

	local main = Create.new("Frame", {
		Name = "KeyGate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, self._height),
		Parent = root,
	})
	theme:Bind(main, { BackgroundColor3 = "Window" })
	theme:Corner(main, "Window")
	theme:Stroke(main, "Stroke", 1)
	local pop = Create.new("UIScale", { Scale = 0.92, Parent = main })
	self._main, self._pop = main, pop
	if cfg.Effects ~= "Lite" then
		Effects.shadow(self, main, pop)
		Effects.windowGlow(self, main)
	end

	local header = Create.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER),
		Parent = main,
	})
	local icon = Icons.Make(header, cfg.Icon or "mark:cross", cfg.Title, 36, { Tint = false, Corner = 8, Theme = theme })
	icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
	icon.Frame.Position = UDim2.new(0, 16, 0.5, 0)
	if icon.Kind ~= "image" then
		icon.Frame.BackgroundTransparency = 0
		theme:Bind(icon.Frame, { BackgroundColor3 = "Control" })
		Create.Corner(icon.Frame, 8)
		self._maid:Give(theme:Watch(function(t)
			icon:Paint(t.Colors.Accent)
		end))
	end
	local title = Create.new("TextLabel", {
		Position = UDim2.new(0, 64, 0, 15),
		Size = UDim2.new(1, -112, 0, 20),
		Text = cfg.Title,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	theme:Text(title, "Text", "Bold", "Header")
	local subtitle = Create.new("TextLabel", {
		Position = UDim2.new(0, 64, 0, 36),
		Size = UDim2.new(1, -112, 0, 16),
		Text = cfg.Subtitle or "Enter your key to continue",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	theme:Text(subtitle, "TextDim", "Regular", "Small")
	Effects.accentLine(self, main, Vector2.new(0, 0), UDim2.new(0, 16, 0, HEADER - 1), UDim2.new(1, -32, 0, 1))

	local close = Create.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(28, 28),
		Parent = header,
	})
	theme:Corner(close, "Control")
	local _, closeParts = Glyphs.cross(close, 14)
	local closeHover = false
	local function paintClose()
		local c = theme:Get().Colors
		close.BackgroundColor3 = c.ControlHover
		close.BackgroundTransparency = closeHover and 0.35 or 1
		Glyphs.paint(closeParts, closeHover and c.Danger or c.TextMuted)
	end
	self._maid:Give(theme:Watch(paintClose))
	self._maid:Give(close.MouseEnter:Connect(function()
		closeHover = true
		paintClose()
	end))
	self._maid:Give(close.MouseLeave:Connect(function()
		closeHover = false
		paintClose()
	end))
	self._maid:Give(close.Activated:Connect(function()
		self:Destroy()
	end))

	local body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, HEADER),
		Size = UDim2.new(1, 0, 1, -HEADER),
		Parent = main,
	})
	Create.Padding(body, 16, 14, 16, 16)
	Create.List(body, Enum.FillDirection.Vertical, 10)

	local inputWrap = Create.new("Frame", {
		Name = "Input",
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 1,
		Parent = body,
	})
	theme:Bind(inputWrap, { BackgroundColor3 = "Control" })
	theme:Corner(inputWrap, "Control")
	local inputStroke = theme:Stroke(inputWrap, "Stroke", 1)
	local box = Create.new("TextBox", {
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		PlaceholderText = "Paste your key",
		ClipsDescendants = true,
		Parent = inputWrap,
	})
	theme:Text(box, "Text", "Medium", "Body")
	theme:Bind(box, { PlaceholderColor3 = "TextMuted" })
	self._box = box
	self._maid:Give(box.Focused:Connect(function()
		inputStroke.Color = theme:Get().Colors.Accent
	end))
	self._maid:Give(box.FocusLost:Connect(function(enterPressed)
		inputStroke.Color = theme:Get().Colors.Stroke
		if enterPressed then
			self:_submit(box.Text)
		end
	end))

	local status = Create.new("TextLabel", {
		Name = "Status",
		Size = UDim2.new(1, 0, 0, 32),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Parent = body,
	})
	theme:Bind(status, {
		Font = function(t)
			return t.Font.Regular
		end,
		TextSize = function(t)
			return t.TextSize.Small
		end,
	})
	self._status = status
	self._maid:Give(theme:Watch(function()
		self:_paintStatus()
	end))

	local verify, verifyApi = PushButton.new(theme, body, "Verify key", "Accent", 3, UDim2.new(1, 0, 0, 44))
	self._verify, self._verifyApi = verify, verifyApi
	self._maid:Give(verify.Activated:Connect(function()
		self:_submit(box.Text)
	end))

	if hasRemember then
		local row = Create.new("TextButton", {
			Name = "Remember",
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 4,
			Parent = body,
		})
		local check = Create.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			Parent = row,
		})
		Create.Corner(check, 4)
		local checkStroke = Create.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1, Parent = check })
		local dot = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(8, 8),
			Parent = check,
		})
		Create.Corner(dot, 2)
		local label = Create.new("TextLabel", {
			Position = UDim2.new(0, 26, 0, 0),
			Size = UDim2.new(1, -26, 1, 0),
			Text = "Remember key on this device",
			Parent = row,
		})
		theme:Text(label, "TextDim", "Regular", "Small")
		local function paintCheck()
			local c = theme:Get().Colors
			check.BackgroundColor3 = self._remember and c.Accent or c.Control
			checkStroke.Color = self._remember and c.Accent or c.TextMuted
			dot.Visible = self._remember
			dot.BackgroundColor3 = c.AccentText
		end
		self._maid:Give(theme:Watch(paintCheck))
		self._maid:Give(row.Activated:Connect(function()
			self._remember = not self._remember
			paintCheck()
		end))
	end

	if #links > 0 then
		local row = Create.new("Frame", {
			Name = "Links",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 5,
			Parent = body,
		})
		Create.List(row, Enum.FillDirection.Horizontal, 8)
		local count = #links
		for index, link in ipairs(links) do
			local button = PushButton.new(
				theme,
				row,
				link.Name,
				"Default",
				index,
				UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0)
			)
			self._maid:Give(button.Activated:Connect(function()
				self:_openLink(link)
			end))
		end
	end

	local dragStart
	Drag.bind(header, {
		OnStart = function()
			dragStart = self._offset
		end,
		OnDelta = function(delta)
			if not dragStart then
				return
			end
			local vp = self:_viewport()
			local offset = dragStart + delta / self._uiScale
			self._offset = Vector2.new(
				math.clamp(offset.X, -(vp.X / 2 - 80), vp.X / 2 - 80),
				math.clamp(offset.Y, -(vp.Y / 2 - 40), vp.Y / 2 - 40)
			)
			main.Position = UDim2.new(0.5, self._offset.X, 0.5, self._offset.Y)
		end,
	}, self._maid)

	self._maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end))
	self:_layout()

	local env = Env()
	local preset = cfg.Key
	if not preset and type(env.script_key) == "string" and env.script_key ~= "" then
		preset = env.script_key
	end
	local fromFile = false
	if not preset and self._saveEnabled then
		preset = readSaved(self._file)
		fromFile = preset ~= nil
	end
	if preset then
		box.Text = preset
		self._silent, self._presetFromFile = true, fromFile
		self:_submit(preset)
	else
		self:_show()
	end
	return self
end

function KeyGate:_viewport()
	return self._gui.AbsoluteSize / self._uiScale
end

function KeyGate:_layout()
	local abs = self._gui.AbsoluteSize
	if abs.X <= 0 or abs.Y <= 0 then
		return
	end
	local scale = math.clamp(math.min(abs.Y / (self._height + 60), abs.X / 420), 0.6, 1)
	self._uiScale = scale
	self._rootScale.Scale = scale
	self._root.Size = UDim2.fromOffset(abs.X / scale, abs.Y / scale)
	self._main.Size = UDim2.fromOffset(math.min(WIDTH, abs.X / scale - 24), self._height)
end

function KeyGate:_show()
	if self._shown or self._destroyed then
		return
	end
	self._shown = true
	self._gui.Enabled = true
	Tween.play(self._pop, { Scale = 1 }, self.Theme:Get().Animation.Normal)
end

function KeyGate:_paintStatus()
	local c = self.Theme:Get().Colors
	self._status.Text = self._statusText
	self._status.TextColor3 = c[STATUS_COLORS[self._statusKind]] or c.TextDim
end

function KeyGate:SetStatus(text, kind)
	self._statusText = tostring(text or "")
	self._statusKind = STATUS_COLORS[kind] and kind or "Info"
	if not self._destroyed then
		self:_paintStatus()
	end
end

function KeyGate:_openLink(link)
	local copied = false
	if setclipboard then
		copied = pcall(setclipboard, link.Url)
	end
	if copied then
		self:SetStatus(link.Name .. " link copied to your clipboard.", "Info")
	else
		self:SetStatus(link.Url, "Info")
	end
end

function KeyGate:_submit(rawKey)
	if self._busy or self._locked or self._destroyed or self._done then
		return
	end
	local key = trim(rawKey)
	if key == "" then
		self:SetStatus("Enter your key first.", "Error")
		return
	end
	self._busy = true
	self._verifyApi.SetDisabled(true)
	self:SetStatus("Checking key...", "Info")

	local finished = false
	task.delay(self._timeout, function()
		if not finished and not self._destroyed then
			finished = true
			self:_failed("The key service did not respond. Try again.")
		end
	end)
	task.spawn(function()
		local ok, valid, message, data = pcall(self._validate, key)
		if finished or self._destroyed then
			return
		end
		finished = true
		if not ok then
			self:_failed("Key check failed. Try again.")
		elseif valid then
			self:_succeed(key, data, message)
		else
			self:_failed(message or "That key is not valid.")
		end
	end)
end

function KeyGate:_failed(message)
	self._busy = false
	if self._silent then
		self._silent = false
		if self._presetFromFile then
			writeSaved(self._file, "")
			message = "Your saved key is no longer valid."
		end
		self:_show()
	end
	self._fails = self._fails + 1
	self:SetStatus(message, "Error")
	if self._fails >= self._maxAttempts then
		self:_lock()
	else
		self._verifyApi.SetDisabled(false)
	end
end

function KeyGate:_lock()
	self._locked = true
	task.spawn(function()
		for remaining = self._cooldown, 1, -1 do
			if self._destroyed then
				return
			end
			self:SetStatus("Too many attempts. Try again in " .. remaining .. "s.", "Error")
			task.wait(1)
		end
		if self._destroyed then
			return
		end
		self._locked, self._fails = false, 0
		self._verifyApi.SetDisabled(false)
		self:SetStatus("You can try again.", "Info")
	end)
end

function KeyGate:_succeed(key, data, message)
	self._busy = false
	self._done = true
	self._silent = false
	if self._saveEnabled then
		writeSaved(self._file, self._remember and key or "")
	end
	self:SetStatus(message or "Key accepted.", "Success")
	self._result = { true, key, data }
	local callback = self._cfg.OnSuccess
	if callback then
		task.spawn(function()
			local ok, err = pcall(callback, key, data)
			if not ok then
				warn("[UI] OnSuccess errored: " .. tostring(err))
			end
		end)
	end
	self:_resolve()
	task.delay(self._shown and 0.7 or 0, function()
		self:Destroy()
	end)
end

function KeyGate:_resolve()
	local waiters = self._waiters
	self._waiters = {}
	for _, thread in ipairs(waiters) do
		task.spawn(thread, table.unpack(self._result, 1, 3))
	end
end

function KeyGate:Wait()
	if self._result then
		return table.unpack(self._result, 1, 3)
	end
	self._waiters[#self._waiters + 1] = coroutine.running()
	return coroutine.yield()
end

function KeyGate:_onDestroy(fn)
	self._destroyCallbacks[#self._destroyCallbacks + 1] = fn
end

function KeyGate:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if not self._done then
		self._done = true
		self._result = { false }
		local callback = self._cfg.OnClose
		if callback then
			pcall(callback)
		end
		self:_resolve()
	end
	for _, fn in ipairs(self._destroyCallbacks) do
		pcall(fn)
	end
	self._maid:Destroy()
end

return KeyGate
end

__defs["core/keylist"] = function()
local Create = require("util/create")
local Tween = require("util/tween")
local Drag = require("util/drag")
local Maid = require("util/maid")
local Validate = require("util/validate")

local KeyList = {}
KeyList.__index = KeyList

local Entry = {}
Entry.__index = Entry

local DEFAULT_WIDTH = 210
local COLOR_TOKENS = { Accent = true, Success = true, Warning = true, Danger = true, AccentAlt = true }

local SHOW_WHEN = { Minimized = true, Hidden = true, Closed = true, Always = true }

local SHORT = {
	LeftShift = "LShift",
	RightShift = "RShift",
	LeftControl = "LCtrl",
	RightControl = "RCtrl",
	LeftAlt = "LAlt",
	RightAlt = "RAlt",
	Backspace = "Bksp",
	Return = "Enter",
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
}

local function toKey(value)
	if value == nil then
		return nil
	end
	if typeof(value) == "EnumItem" then
		return value
	end
	if type(value) == "string" and Enum.KeyCode[value] then
		return Enum.KeyCode[value]
	end
	error("[UI] KeybindList: expected an Enum.KeyCode or a key name like \"F\"", 0)
end

local function keyText(key)
	if not key then
		return "--"
	end
	return SHORT[key.Name] or key.Name
end

local function checkColor(where, color)
	if color == nil or typeof(color) == "Color3" or COLOR_TOKENS[color] then
		return
	end
	error(("[UI] %s: Color must be a Color3 or one of Accent, AccentAlt, Success, Warning, Danger"):format(where), 0)
end

local function resolveColor(color, colors)
	if typeof(color) == "Color3" then
		return color
	end
	return colors[color or "Accent"] or colors.Accent
end

local function styleText(theme, label, font, size)
	theme:Bind(label, {
		Font = function(t)
			return t.Font[font]
		end,
		TextSize = function(t)
			return t.TextSize[size]
		end,
	})
end

local function shouldShow(mode, state)
	if mode == "Always" then
		return true
	end
	if mode == "Minimized" then
		return state == "minimized"
	end
	if mode == "Hidden" then
		return state == "hidden"
	end
	return state ~= "open"
end

-- ---------------------------------------------------------------- entry

function Entry:_paint(animate)
	if self._destroyed then
		return
	end
	local list = self._list
	local t = list._window.Theme:Get()
	local c = t.Colors
	local on = self._active
	local tone = resolveColor(self._color or list._color, c)

	local function apply(inst, props)
		if animate then
			Tween.play(inst, props, t.Animation.Fast)
		else
			for key, value in pairs(props) do
				inst[key] = value
			end
		end
	end

	apply(self._row, { BackgroundColor3 = tone, BackgroundTransparency = on and 0.86 or 1 })
	apply(self._dot, { BackgroundColor3 = on and tone or c.ControlPressed })
	apply(self._name, { TextColor3 = on and c.Text or c.TextMuted })
	apply(self._badge, { BackgroundColor3 = c.Control })
	apply(self._badgeText, { TextColor3 = on and tone or (self._key and c.TextDim or c.TextMuted) })
	apply(self._badgeStroke, { Color = on and tone or c.Stroke })
end

function Entry:SetActive(active)
	active = active and true or false
	if active == self._active then
		return
	end
	self._active = active
	self:_paint(true)
	self._list:_refreshCount()
end

function Entry:GetActive()
	return self._active
end

function Entry:SetKey(key)
	self._key = toKey(key)
	self._badgeText.Text = keyText(self._key)
	self:_paint(false)
end

function Entry:GetKey()
	return self._key
end

function Entry:SetName(text)
	self._nameText = tostring(text)
	self._name.Text = self._nameText
end

function Entry:SetColor(color)
	checkColor("Entry:SetColor", color)
	self._color = color
	self:_paint(true)
end

function Entry:Remove()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._maid:Destroy()
	self._row:Destroy()
	self._list:_forget(self)
end

Entry.Destroy = Entry.Remove

-- ----------------------------------------------------------------- list

local function buildEntry(list, cfg)
	local window = list._window
	local theme = window.Theme
	local touch = window._ctx.Touch
	local height = touch and 30 or 26

	local self = setmetatable({}, Entry)
	self._list = list
	self._maid = Maid.new()
	self._active = cfg.Active == true
	self._key = toKey(cfg.Key)
	self._color = cfg.Color
	self._nameText = cfg.Name
	self.Id = cfg.Id

	local row = Create.new("Frame", {
		Name = "Entry",
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = list:_nextOrder(),
		Parent = list._body,
	})
	theme:Corner(row, "Control")
	self._row = row

	local dot = Create.new("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		Parent = row,
	})
	Create.Corner(dot, UDim.new(1, 0))
	self._dot = dot

	local badge = Create.new("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(0, height - 8),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = row,
	})
	theme:Corner(badge, "Control")
	local badgeStroke = Create.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Parent = badge,
	})
	Create.Padding(badge, 8, 0, 8, 0)
	local badgeText = Create.new("TextLabel", {
		Name = "Text",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = keyText(self._key),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = badge,
	})
	styleText(theme, badgeText, "Medium", "Small")
	self._badge, self._badgeStroke, self._badgeText = badge, badgeStroke, badgeText

	local name = Create.new("TextLabel", {
		Name = "Name",
		Position = UDim2.new(0, 24, 0, 0),
		Size = UDim2.new(1, -(24 + 6), 1, 0),
		Text = cfg.Name,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	styleText(theme, name, "Medium", "Body")
	self._name = name

	-- keep the name clear of the key badge, whatever width the key text ends up at
	local function reserve()
		name.Size = UDim2.new(1, -(24 + badge.AbsoluteSize.X / math.max(window._uiScale, 0.01) + 12), 1, 0)
	end
	self._maid:Give(badge:GetPropertyChangedSignal("AbsoluteSize"):Connect(reserve))
	reserve()

	self._maid:Give(theme:Watch(function()
		self:_paint(false)
	end))
	return self
end

function KeyList:_nextOrder()
	self._order = self._order + 1
	return self._order
end

function KeyList:_forget(entry)
	for i, item in ipairs(self._entries) do
		if item == entry then
			table.remove(self._entries, i)
			break
		end
	end
	if entry.Id ~= nil and self._byId[entry.Id] == entry then
		self._byId[entry.Id] = nil
	end
	self:_refreshCount()
	self:_sync()
end

function KeyList:_refreshCount()
	local active = 0
	for _, entry in ipairs(self._entries) do
		if entry._active then
			active = active + 1
		end
	end
	self._count.Text = ("%d / %d"):format(active, #self._entries)
end

function KeyList:Add(cfg)
	if self._destroyed then
		return nil
	end
	Validate.check("KeybindList:Add", cfg, {
		Name = "string!",
		Id = "string",
		Key = "EnumItem|string",
		Active = "boolean",
	})
	checkColor("KeybindList:Add", cfg.Color)
	if cfg.Id ~= nil and self._byId[cfg.Id] then
		error(("[UI] KeybindList:Add: an entry with Id '%s' already exists"):format(cfg.Id), 0)
	end
	local entry = buildEntry(self, cfg)
	self._entries[#self._entries + 1] = entry
	if cfg.Id ~= nil then
		self._byId[cfg.Id] = entry
	end
	self:_refreshCount()
	self:_sync()
	return entry
end

function KeyList:Get(id)
	return self._byId[id]
end

-- Mirror existing library controls into one entry:
--   list:Link({ Name = "Kill Aura", Toggle = toggleControl, Keybind = keybindControl })
-- The entry's lit state follows the toggle; its key badge follows the keybind.
function KeyList:Link(cfg)
	Validate.check("KeybindList:Link", cfg, {
		Name = "string!",
		Id = "string",
		Color = "Color3|string",
		Toggle = "table",
		Keybind = "table",
	})
	local toggle, keybind = cfg.Toggle, cfg.Keybind
	local entry = self:Add({
		Name = cfg.Name,
		Id = cfg.Id,
		Color = cfg.Color,
		Key = keybind and keybind:Get() or nil,
		Active = toggle and toggle:Get() == true or false,
	})
	if not entry then
		return nil
	end
	if toggle then
		entry._maid:Give(toggle:OnChange(function(value)
			entry:SetActive(value)
		end))
	end
	if keybind then
		entry._maid:Give(keybind:OnChange(function(key)
			entry:SetKey(key)
		end))
	end
	return entry
end

function KeyList:SetTitle(text)
	self._title.Text = string.upper(tostring(text))
end

function KeyList:SetShowWhen(mode)
	if not SHOW_WHEN[mode] then
		error("[UI] KeybindList: ShowWhen must be Minimized, Hidden, Closed or Always", 0)
	end
	self._showWhen = mode
	self:_sync()
end

function KeyList:SetColor(color)
	checkColor("KeybindList:SetColor", color)
	self._color = color or "Accent"
	for _, entry in ipairs(self._entries) do
		entry:_paint(true)
	end
end

function KeyList:SetVisible(visible)
	self._forceHidden = not visible
	self:_sync()
end

function KeyList:_place()
	if self._destroyed then
		return
	end
	local window = self._window
	local vp = window:_viewport()
	local frame = self.Frame
	local size = frame.AbsoluteSize / (math.max(window._uiScale, 0.01) * math.max(self._scale.Scale, 0.1))
	if size.X < 8 then
		size = Vector2.new(self._width, 60)
	end
	local pos = self.Pos or Vector2.new(12, vp.Y * 0.35 + 56)
	pos = Vector2.new(
		math.clamp(pos.X, 0, math.max(0, vp.X - size.X)),
		math.clamp(pos.Y, 0, math.max(0, vp.Y - size.Y))
	)
	self.Pos = pos
	frame.Position = UDim2.fromOffset(math.floor(pos.X), math.floor(pos.Y))
end

-- Show or hide the panel to match the window state (called by Window:_transition).
function KeyList:_sync()
	if self._destroyed then
		return
	end
	local want = #self._entries > 0
		and not self._forceHidden
		and shouldShow(self._showWhen, self._window._state)
	if want == self._shown then
		return
	end
	self._shown = want
	self._token = self._token + 1
	local token = self._token
	local anim = self._window.Theme:Get().Animation
	if want then
		self.Frame.Visible = true
		self:_place()
		Tween.play(self._scale, { Scale = 1 }, anim.Normal, Enum.EasingStyle.Back)
	else
		local tween = Tween.play(self._scale, { Scale = 0 }, anim.Fast)
		tween.Completed:Connect(function()
			if self._token == token then
				self.Frame.Visible = false
			end
		end)
	end
end

function KeyList:IsShown()
	return self._shown
end

function KeyList:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._maid:Destroy()
	for _, entry in ipairs(self._entries) do
		entry._destroyed = true
		entry._maid:Destroy()
	end
	self._entries, self._byId = {}, {}
	self.Frame:Destroy()
	if self._window._keylist == self then
		self._window._keylist = nil
	end
end

function KeyList.new(window, cfg)
	Validate.check("CreateKeybindList", cfg, {
		Title = "string",
		ShowWhen = "string",
		Width = "number",
		Position = "Vector2",
		Color = "Color3|string",
		Draggable = "boolean",
	})
	local showWhen = cfg.ShowWhen or "Closed"
	if not SHOW_WHEN[showWhen] then
		error("[UI] CreateKeybindList: ShowWhen must be Minimized, Hidden, Closed or Always", 0)
	end
	checkColor("CreateKeybindList", cfg.Color)

	local theme = window.Theme
	local touch = window._ctx.Touch
	local self = setmetatable({}, KeyList)
	self._window = window
	self._maid = Maid.new()
	self._entries, self._byId = {}, {}
	self._order = 0
	self._token = 0
	self._shown = false
	self._showWhen = showWhen
	self._color = cfg.Color or "Accent"
	self._width = math.max(150, cfg.Width or DEFAULT_WIDTH)
	self.Pos = cfg.Position
	window._maid:Give(self._maid)

	-- Same visual language as the minimized pill: Window fill, Pill transparency,
	-- accent -> accent-alt gradient stroke, Window-radius corners.
	local frame = Create.new("Frame", {
		Name = "KeybindList",
		Size = UDim2.fromOffset(self._width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Visible = false,
		ZIndex = 19,
		Parent = window._root,
	})
	theme:Bind(frame, {
		BackgroundColor3 = "Window",
		BackgroundTransparency = function(t)
			return t.Transparency.Pill
		end,
	})
	theme:Corner(frame, "Window")
	local stroke = Create.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 2,
		Color = Color3.new(1, 1, 1),
		Parent = frame,
	})
	local gradient = Create.new("UIGradient", { Parent = stroke })
	theme:Bind(gradient, {
		Color = function(t)
			return ColorSequence.new(t.Colors.Accent, t.Colors.AccentAlt)
		end,
	})
	Create.List(frame, Enum.FillDirection.Vertical, 0)
	Create.Padding(frame, 8, 6, 8, 8)
	self.Frame = frame
	self._scale = Create.new("UIScale", { Scale = 0, Parent = frame })

	local header = Create.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and 32 or 28),
		LayoutOrder = 1,
		Parent = frame,
	})
	local title = Create.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Text = string.upper(cfg.Title or "Keybinds"),
		Parent = header,
	})
	theme:Text(title, "TextDim", "Bold", "Small")
	local count = Create.new("TextLabel", {
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0, 56, 1, 0),
		Text = "0 / 0",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	theme:Text(count, "TextMuted", "Medium", "Small")
	self._title, self._count = title, count

	local divider = Create.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 2,
		Parent = frame,
	})
	theme:Bind(divider, { BackgroundColor3 = "Divider" })

	local body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = frame,
	})
	Create.List(body, Enum.FillDirection.Vertical, 2)
	Create.Padding(body, 0, 6, 0, 0)
	self._body = body

	if cfg.Draggable ~= false then
		local start
		Drag.bind(frame, {
			Threshold = 6,
			OnStart = function()
				start = self.Pos
			end,
			OnDelta = function(delta)
				if start then
					self.Pos = start + delta / window._uiScale
					self:_place()
				end
			end,
		}, self._maid)
	end

	self._maid:Give(frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if frame.Visible then
			self:_place()
		end
	end))

	return self
end

return KeyList
end

__defs["core/popup"] = function()
local Create = require("util/create")
local Maid = require("util/maid")
local Tween = require("util/tween")

local Popup = {}

function Popup.open(window, anchor, opts)
	window:_closePopup()
	local theme = window.Theme
	local anim = theme:Get().Animation
	local scale = math.max(window._rootScale.Scale, 0.01)
	local rootPos = window._root.AbsolutePosition
	local aPos = (anchor.AbsolutePosition - rootPos) / scale
	local aSize = anchor.AbsoluteSize / scale
	local vp = window:_viewport()

	local width = math.min(opts.Width or aSize.X, vp.X - 16)
	local gap = 4
	local below = vp.Y - (aPos.Y + aSize.Y) - gap - 8
	local above = aPos.Y - gap - 8
	local placeBelow = opts.Height <= below or below >= above
	local height = math.max(60, math.min(opts.Height, placeBelow and below or above))

	local x = opts.AlignRight and (aPos.X + aSize.X - width) or aPos.X
	x = math.clamp(x, 8, math.max(8, vp.X - width - 8))
	local y = placeBelow and (aPos.Y + aSize.Y + gap) or (aPos.Y - gap)
	local anchorY = placeBelow and 0 or 1

	local obj = { Maid = Maid.new() }
	local closed = false

	local blocker = Create.new("TextButton", {
		Name = "PopupBlocker",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 48,
		Parent = window._overlay,
	})
	local frame = Create.new("Frame", {
		Name = "Popup",
		AnchorPoint = Vector2.new(0, anchorY),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width, 0),
		ClipsDescendants = true,
		ZIndex = 49,
		Parent = window._overlay,
	})
	theme:Bind(frame, { BackgroundColor3 = "Card" })
	theme:Corner(frame, "Control")
	theme:Stroke(frame, "Stroke", 1)

	obj.Body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, anchorY),
		Position = UDim2.new(0, 0, anchorY, 0),
		Size = UDim2.new(1, 0, 0, height),
		Parent = frame,
	})
	obj.Width, obj.Height = width, height

	function obj.Close()
		if closed then
			return
		end
		closed = true
		if window._popup == obj then
			window._popup = nil
		end
		obj.Maid:Destroy()
		blocker:Destroy()
		local tween = Tween.play(frame, { Size = UDim2.fromOffset(width, 0) }, anim.Fast)
		tween.Completed:Connect(function()
			frame:Destroy()
		end)
		if opts.OnClose then
			opts.OnClose()
		end
	end

	blocker.Activated:Connect(obj.Close)
	window._popup = obj
	Tween.play(frame, { Size = UDim2.fromOffset(width, height) }, anim.Normal)
	return obj
end

return Popup
end

__defs["core/pushbutton"] = function()
local Create = require("util/create")
local Tween = require("util/tween")

local PushButton = {}

function PushButton.new(theme, parent, text, kind, order, size)
	kind = kind or "Default"
	local button = Create.new("TextButton", {
		Name = text,
		Size = size or UDim2.fromScale(1, 1),
		Text = text,
		BackgroundTransparency = 0,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	theme:Corner(button, "Control")
	local stroke = theme:Stroke(button, "Stroke", 1)
	theme:Bind(button, {
		Font = function(t)
			return t.Font.Medium
		end,
		TextSize = function(t)
			return t.TextSize.Body
		end,
	})

	local hover, down, disabled = false, false, false
	local function paint(animate)
		local th = theme:Get()
		local c = th.Colors
		local bg, textColor
		if kind == "Accent" then
			bg, textColor = c.Accent, c.AccentText
		elseif kind == "Danger" then
			bg, textColor = c.Danger, c.AccentText
		else
			bg = down and c.ControlPressed or (hover and c.ControlHover or c.Control)
			textColor = c.Text
		end
		local transparency = (kind ~= "Default") and (down and 0.25 or (hover and 0.1 or 0)) or 0
		if disabled then
			transparency = 0.5
			textColor = kind == "Default" and c.TextMuted or textColor
		end
		button.TextColor3 = textColor
		stroke.Color = kind == "Default" and c.Stroke or bg
		if animate then
			Tween.play(button, { BackgroundColor3 = bg, BackgroundTransparency = transparency }, th.Animation.Fast)
		else
			button.BackgroundColor3 = bg
			button.BackgroundTransparency = transparency
		end
	end
	paint(false)

	local watcher = theme:Watch(function()
		paint(false)
	end)
	button.Destroying:Connect(function()
		watcher.Disconnect()
	end)
	button.MouseEnter:Connect(function()
		hover = true
		paint(true)
	end)
	button.MouseLeave:Connect(function()
		hover, down = false, false
		paint(true)
	end)
	button.MouseButton1Down:Connect(function()
		down = true
		paint(true)
	end)
	button.MouseButton1Up:Connect(function()
		down = false
		paint(true)
	end)

	local api = {}
	function api.SetDisabled(value)
		disabled = value and true or false
		paint(true)
	end
	function api.IsDisabled()
		return disabled
	end
	return button, api
end

return PushButton
end

__defs["core/tab"] = function()
local Create = require("util/create")
local Maid = require("util/maid")
local Tween = require("util/tween")
local Validate = require("util/validate")
local Icons = require("core/icons")
local Card = require("core/card")

local Tab = {}
Tab.__index = Tab

function Tab.new(window, cfg, groupItems, group)
	Validate.check("CreateTab", cfg, { Name = "string!", Icon = "string|number|boolean", Group = "string", Tint = "boolean", Heading = "string", Description = "string" })
	local theme = window.Theme
	local th = theme:Get()
	local ctx = window._ctx

	local self = setmetatable({}, Tab)
	self.Window = window
	self.Name = cfg.Name
	self._maid = window._maid:Give(Maid.new())
	self._count = 0
	self._cards = {}
	self._active, self._hover = false, false
	self._group = group

	local button = Create.new("TextButton", {
		Name = cfg.Name,
		Size = UDim2.new(1, 0, 0, ctx.TabHeight),
		BackgroundTransparency = 1,
		Parent = groupItems,
	})
	theme:Corner(button, "Control")
	local badge = Create.new("Frame", {
		Name = "IconBadge",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Parent = button,
	})
	Create.Corner(badge, UDim.new(1, 0))
	local badgeGradient = Create.new("UIGradient", { Enabled = false, Parent = badge })
	theme:Bind(badgeGradient, {
		Color = function(t)
			return ColorSequence.new(t.Colors.Accent, t.Colors.AccentAlt)
		end,
	})
	local noIcon = cfg.Icon == false or window._tabIcons == false
	local iconSpec = cfg.Icon
	if iconSpec == false then
		iconSpec = nil
	elseif iconSpec == nil and not noIcon then
		iconSpec = Icons.Guess(cfg.Name)
	end
	local icon = Icons.Make(button, iconSpec, cfg.Name, 22, { Tint = cfg.Tint })
	local label = Create.new("TextLabel", {
		Name = "Label",
		Position = UDim2.new(0, 50, 0, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Text = cfg.Name,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})
	theme:Bind(label, {
		Font = function(t)
			return t.Font.Medium
		end,
		TextSize = function(t)
			return t.TextSize.Body
		end,
	})
	self._noIcon = noIcon
	self.Button, self._icon, self._label = button, icon, label
	self._badge, self._badgeGradient = badge, badgeGradient
	self._maid:Give(button)

	local page = Create.new("ScrollingFrame", {
		Name = cfg.Name,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = ctx.Touch and 4 or 3,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Visible = false,
		Parent = window.Pages,
	})
	theme:Bind(page, { ScrollBarImageColor3 = "TextMuted" })
	self.Page = page
	self._maid:Give(page)

	local wrap = Create.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = page,
	})
	local pad = th.Spacing.Padding
	Create.Padding(wrap, pad, pad, pad, pad)
	Create.List(wrap, Enum.FillDirection.Vertical, 12)

	if cfg.Heading or cfg.Description then
		local heading = Create.new("Frame", {
			Name = "Heading",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = wrap,
		})
		Create.List(heading, Enum.FillDirection.Vertical, 4)
		if cfg.Heading then
			local title = Create.new("TextLabel", {
				Name = "Title",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = cfg.Heading,
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				LayoutOrder = 1,
				Parent = heading,
			})
			theme:Bind(title, {
				Font = function(t)
					return t.Font.Bold
				end,
				TextSize = function(t)
					return t.TextSize.Title + 6
				end,
			})
			local titleGradient = Create.new("UIGradient", { Parent = title })
			theme:Bind(titleGradient, {
				Color = function(t)
					return ColorSequence.new(t.Colors.Text, t.Colors.Accent)
				end,
			})
		end
		if cfg.Description then
			local text = Create.new("TextLabel", {
				Name = "Description",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = cfg.Description,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				LayoutOrder = 2,
				Parent = heading,
			})
			theme:Text(text, "TextDim", "Regular", "Small")
		end
	end

	local container = Create.new("Frame", {
		Name = "Columns",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = wrap,
	})
	self._columnsLayout = Create.List(container, Enum.FillDirection.Horizontal, th.Spacing.Gap)
	self._columnsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	self._columns = {}
	for i = 1, 2 do
		local column = Create.new("Frame", {
			Name = "Column" .. i,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -th.Spacing.Gap / 2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = container,
		})
		Create.List(column, Enum.FillDirection.Vertical, th.Spacing.Gap)
		self._columns[i] = column
	end

	self._maid:Give(button.Activated:Connect(function()
		window:SelectTab(self)
	end))
	self._maid:Give(button.MouseEnter:Connect(function()
		self._hover = true
		self:_renderButton(true)
	end))
	self._maid:Give(button.MouseLeave:Connect(function()
		self._hover = false
		self:_renderButton(true)
	end))
	self._maid:Give(theme:Watch(function()
		self:_renderButton(false)
	end))

	self:_setRail(window._rail or false)
	self:_setColumns(window._twoCol and 2 or 1)
	return self
end

function Tab:_renderButton(animate)
	local th = self.Window.Theme:Get()
	local c = th.Colors
	local active, hover = self._active, self._hover
	local rowTransparency = active and 0.9 or (hover and 0.5 or 1)
	local rowColor = active and c.Accent or c.Control
	local badgeTransparency = active and 0 or 1
	self._label.TextColor3 = (active or hover) and c.Text or c.TextDim
	self._icon:Paint(active and c.AccentText or c.TextDim, active or hover)
	self._badgeGradient.Enabled = active
	if animate then
		Tween.play(self.Button, { BackgroundTransparency = rowTransparency, BackgroundColor3 = rowColor }, th.Animation.Fast)
		Tween.play(self._badge, { BackgroundTransparency = badgeTransparency }, th.Animation.Fast)
	else
		self.Button.BackgroundTransparency = rowTransparency
		self.Button.BackgroundColor3 = rowColor
		self._badge.BackgroundTransparency = badgeTransparency
	end
end

function Tab:_setActive(active)
	self._active = active
	self:_renderButton(true)
	if active then
		self.Page.Position = UDim2.new(0, 0, 0, 10)
		self.Page.Visible = true
		Tween.play(self.Page, { Position = UDim2.new(0, 0, 0, 0) }, self.Window.Theme:Get().Animation.Normal)
	else
		self.Page.Visible = false
	end
end

function Tab:_setRail(rail)
	if self._railApplied == rail then
		return
	end
	self._railApplied = rail
	self._rail = rail
	self._label.Visible = not rail
	local frame = self._icon.Frame
	local badge = self._badge
	if rail then
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.new(0.5, 0, 0.5, 0)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.5, 0, 0.5, 0)
	else
		frame.AnchorPoint = Vector2.new(0, 0.5)
		frame.Position = UDim2.new(0, 14, 0.5, 0)
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 10, 0.5, 0)
	end
	if self._noIcon then
		-- no icon: hide the icon slot in the full sidebar and start the label at the normal padding
		frame.Visible = rail
		badge.Visible = rail
		self._label.Position = UDim2.new(0, 14, 0, 0)
		self._label.Size = UDim2.new(1, -20, 1, 0)
	end
end

function Tab:_setColumns(count)
	if self._columnCount == count then
		return
	end
	self._columnCount = count
	local gap = self.Window.Theme:Get().Spacing.Gap
	if count == 2 then
		self._columnsLayout.FillDirection = Enum.FillDirection.Horizontal
		for _, column in ipairs(self._columns) do
			column.Size = UDim2.new(0.5, -gap / 2, 0, 0)
		end
	else
		self._columnsLayout.FillDirection = Enum.FillDirection.Vertical
		for _, column in ipairs(self._columns) do
			column.Size = UDim2.new(1, 0, 0, 0)
		end
	end
end

function Tab:_applyFilter(query)
	local nameMatch = query ~= "" and string.find(string.lower(self.Name), query, 1, true) ~= nil
	local total = 0
	for _, card in ipairs(self._cards) do
		total = total + card:_applyFilter(nameMatch and "" or query)
	end
	self.Button.Visible = query == "" or nameMatch or total > 0
end

function Tab:CreateCard(cfg)
	Validate.check("CreateCard", cfg, { Name = "string!", Column = "number" })
	local index = cfg.Column
	if index ~= 1 and index ~= 2 then
		index = (self._count % 2) + 1
	end
	self._count = self._count + 1
	local card = Card.new(self, cfg, self._columns[index])
	self._cards[#self._cards + 1] = card
	return card
end

function Tab:_removeCard(card)
	for index, existing in ipairs(self._cards) do
		if existing == card then
			table.remove(self._cards, index)
			break
		end
	end
end

function Tab:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for index = #self._cards, 1, -1 do
		self._cards[index]:Destroy()
	end
	self.Window:_removeTab(self)
	self._maid:Destroy()
end

function Tab:Select()
	self.Window:SelectTab(self)
end

return Tab
end

__defs["core/toast"] = function()
local Create = require("util/create")
local Tween = require("util/tween")
local Validate = require("util/validate")

local Toast = {}
Toast.__index = Toast

local TYPES = { Info = "Accent", Success = "Success", Warning = "Warning", Error = "Danger" }
local POSITIONS = {
	TopRight = { x = 1, y = 0 },
	BottomRight = { x = 1, y = 1 },
	TopLeft = { x = 0, y = 0 },
	BottomLeft = { x = 0, y = 1 },
}
local MAX_VISIBLE = 5

function Toast.new(window, position)
	local place = POSITIONS[position or "BottomRight"]
	if not place then
		error("[UI] NotifyPosition must be TopRight, BottomRight, TopLeft or BottomLeft", 0)
	end
	local self = setmetatable({ _window = window, _place = place, _active = {}, _order = 0 }, Toast)
	local container = Create.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(place.x, place.y),
		Position = UDim2.new(place.x, place.x == 1 and -12 or 12, place.y, place.y == 1 and -12 or 12),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 55,
		Parent = window._overlay,
	})
	local list = Create.List(container, Enum.FillDirection.Vertical, 8)
	list.HorizontalAlignment = place.x == 1 and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
	list.VerticalAlignment = place.y == 1 and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
	self._container = container
	return self
end

function Toast:_relayout()
	local vp = self._window:_viewport()
	self._container.Size = UDim2.fromOffset(math.min(300, vp.X - 24), 0)
end

function Toast:_dismiss(entry, instant)
	if entry.dismissed then
		return
	end
	entry.dismissed = true
	for index, active in ipairs(self._active) do
		if active == entry then
			table.remove(self._active, index)
			break
		end
	end
	if instant then
		entry.wrapper:Destroy()
		return
	end
	local width = self._container.Size.X.Offset
	local dir = self._place.x == 1 and 1 or -1
	local tween = Tween.play(entry.toast, { Position = UDim2.fromOffset(dir * (width + 40), 0) }, self._window.Theme:Get().Animation.Normal)
	tween.Completed:Connect(function()
		entry.wrapper:Destroy()
	end)
end

function Toast:Push(cfg)
	Validate.check("Notify", cfg, { Title = "string", Content = "string", Duration = "number", Type = "string" })
	if cfg.Title == nil and cfg.Content == nil then
		error("[UI] Notify: needs a Title or Content", 0)
	end
	local token = TYPES[cfg.Type or "Info"]
	if not token then
		error("[UI] Notify: Type must be Info, Success, Warning or Error", 0)
	end

	local window = self._window
	local theme = window.Theme
	while #self._active >= MAX_VISIBLE do
		self:_dismiss(self._active[1], true)
	end

	self._order = self._order + 1
	local wrapper = Create.new("Frame", {
		Name = "ToastWrapper",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self._order,
		Parent = self._container,
	})
	local width = self._container.Size.X.Offset
	local dir = self._place.x == 1 and 1 or -1
	local toast = Create.new("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(dir * (width + 40), 0),
		Parent = wrapper,
	})
	theme:Bind(toast, {
		BackgroundColor3 = "Card",
		BackgroundTransparency = function(t)
			return t.Transparency.Toast
		end,
	})
	theme:Corner(toast, "Card")
	local toastStroke = theme:Stroke(toast, "Stroke", 1)
	toastStroke.Transparency = 0.4

	local bar = Create.new("Frame", {
		Name = "Accent",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(0, 3, 1, -16),
		Parent = toast,
	})
	Create.Corner(bar, UDim.new(1, 0))
	theme:Bind(bar, { BackgroundColor3 = token })

	local body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = toast,
	})
	Create.List(body, Enum.FillDirection.Vertical, 2)
	Create.Padding(body, 20, 10, 12, 10)

	if cfg.Title then
		local title = Create.new("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = cfg.Title,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 1,
			Parent = body,
		})
		theme:Text(title, "Text", "Bold", "Body")
	end
	if cfg.Content then
		local text = Create.new("TextLabel", {
			Name = "Content",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = cfg.Content,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
			Parent = body,
		})
		theme:Text(text, "TextDim", "Regular", "Small")
	end

	local entry = { wrapper = wrapper, toast = toast, dismissed = false }
	self._active[#self._active + 1] = entry

	local click = Create.new("TextButton", { Name = "Dismiss", Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = toast })
	click.Activated:Connect(function()
		self:_dismiss(entry)
	end)

	Tween.play(toast, { Position = UDim2.fromOffset(0, 0) }, theme:Get().Animation.Normal)
	task.delay(cfg.Duration or 4, function()
		if wrapper.Parent then
			self:_dismiss(entry)
		end
	end)

	return {
		Dismiss = function()
			self:_dismiss(entry)
		end,
	}
end

return Toast
end

__defs["core/window"] = function()
local Services = require("util/services")
local Create = require("util/create")
local Maid = require("util/maid")
local Tween = require("util/tween")
local Drag = require("util/drag")
local Validate = require("util/validate")
local ThemeManager = require("theme/manager")
local Icons = require("core/icons")
local Tab = require("core/tab")
local Dock = require("core/dock")
local KeyList = require("core/keylist")
local Mount = require("util/mount")
local Effects = require("core/effects")
local Toast = require("core/toast")
local Dialog = require("core/dialog")

local UserInputService = Services.UserInputService

local Window = {}
Window.__index = Window

local MIN_W, MIN_H = 300, 220
local EDGE = 8
local AUTO_W, AUTO_H, AUTO_MIN = 760, 480, 0.6
local TWO_COLUMN_MIN = 420
local CLOSE = "\u{00D7}"
local MINIMIZE = "\u{2013}"
local CHEVRON = "\u{203A}"

local function topButton(window, parent, text, hoverToken)
	local theme = window.Theme
	local button = Create.new("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Text = text,
		TextSize = 20,
		Parent = parent,
	})
	theme:Corner(button, "Control")
	local hover = false
	local function render(animate)
		local th = theme:Get()
		local c = th.Colors
		button.BackgroundColor3 = c.ControlHover
		local color = hover and c[hoverToken] or c.TextDim
		if animate then
			Tween.play(button, { BackgroundTransparency = hover and 0.3 or 1, TextColor3 = color }, th.Animation.Fast)
		else
			button.BackgroundTransparency = hover and 0.3 or 1
			button.TextColor3 = color
		end
	end
	window._maid:Give(theme:Watch(function()
		render(false)
	end))
	window._maid:Give(button.MouseEnter:Connect(function()
		hover = true
		render(true)
	end))
	window._maid:Give(button.MouseLeave:Connect(function()
		hover = false
		render(true)
	end))
	window._maid:Give(button.MouseButton1Down:Connect(function()
		hover = true
		render(true)
	end))
	window._maid:Give(button.MouseButton1Up:Connect(function()
		hover = false
		render(true)
	end))
	return button
end

local function build(cfg, partial)
	Validate.check("CreateWindow", cfg, {
		Title = "string!",
		Subtitle = "string",
		Icon = "string|number",
		Theme = "string|table",
		ToggleKey = "EnumItem",
		Size = "Vector2",
		Footer = "string|table",
		OnClose = "function",
		Id = "string",
		TouchMode = "boolean",
		Resizable = "boolean",
		Scale = "number",
		NotifyPosition = "string",
		FabIcon = "string|number",
		MinimizeStyle = "string",
		Effects = "string",
		BrandGradient = "boolean",
		Mark = "string",
		TabIcons = "boolean",
		Glow = "number",
	})

	cfg.Icon = cfg.Icon or ("mark:" .. string.lower(cfg.Mark or "cross"))
	local self = setmetatable({}, Window)
	self._maid = Maid.new()
	partial.self = self
	self._tabs = {}
	self._groups = {}
	self._groupOrder = 0
	self._destroyCallbacks = {}
	self._onClose = cfg.OnClose
	self._state = "open"
	self._token = 0
	self._userRail = false
	self._userScale = cfg.Scale
	self._uiScale = 1
	self._toggleKey = cfg.ToggleKey
	self._size = cfg.Size or Vector2.new(640, 420)
	self._tabIcons = cfg.TabIcons ~= false

	local theme = ThemeManager.new(cfg.Theme or "Mono")
	self.Theme = theme
	local th = theme:Get()
	local sp = th.Spacing

	local touch
	if cfg.TouchMode ~= nil then
		touch = cfg.TouchMode
	else
		touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	end
	self._ctx = {
		Theme = theme,
		Touch = touch,
		RowHeight = touch and sp.RowTouch or sp.Row,
		TabHeight = touch and 44 or 38,
		Window = self,
	}

	local gui = Create.new("ScreenGui", {
		Name = "UILib",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
	})
	Mount.gui(gui)
	self._gui = gui
	self._maid:Give(gui)

	local root = Create.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local rootScale = Create.new("UIScale", { Parent = root })
	self._root, self._rootScale = root, rootScale

	local main = Create.new("Frame", { Name = "Window", Parent = root })
	theme:Bind(main, { BackgroundColor3 = "Window" })
	theme:Corner(main, "Window")
	theme:Stroke(main, "Stroke", 1)
	local scale = Create.new("UIScale", { Scale = 0.9, Parent = main })
	self._main, self._scale = main, scale
	if cfg.Effects ~= nil and cfg.Effects ~= "Full" and cfg.Effects ~= "Lite" then
		error("[UI] CreateWindow: Effects must be Full or Lite", 0)
	end
	if cfg.Effects ~= "Lite" then
		Effects.shadow(self, main, scale)
		Effects.windowGlow(self, main)
	end

	local sidebar = Create.new("Frame", { Name = "Sidebar", Size = UDim2.new(0, sp.Sidebar, 1, 0), Parent = main })
	theme:Bind(sidebar, { BackgroundColor3 = "Sidebar" })
	theme:Corner(sidebar, "Window")
	local sideFill = Create.new("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 24, 1, 0),
		Parent = sidebar,
	})
	theme:Bind(sideFill, { BackgroundColor3 = "Sidebar" })
	local sideLine = Create.new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = sidebar,
	})
	theme:Bind(sideLine, { BackgroundColor3 = "Divider" })
	self._sidebar = sidebar
	if cfg.Effects ~= "Lite" then
		Effects.sidebarGlow(self, sidebar)
	end
	Effects.accentLine(self, sidebar, Vector2.new(0, 0), UDim2.new(0, 14, 0, 63), UDim2.new(1, -28, 0, 1))

	local brand = Create.new("Frame", {
		Name = "Brand",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 64),
		Parent = sidebar,
	})
	local badgeStroke
	local brandIcon
	local function styleBrand()
		local isImage = brandIcon.Kind == "image"
		brandIcon.Frame.BackgroundTransparency = isImage and 1 or 0
		if badgeStroke then
			badgeStroke.Enabled = not isImage
		end
	end
	brandIcon = Icons.Make(brand, cfg.Icon, cfg.Title, 36, {
		Tint = false,
		Corner = 8,
		Theme = theme,
		OnChange = function()
			styleBrand()
		end,
	})
	theme:Bind(brandIcon.Frame, { BackgroundColor3 = "Control" })
	Create.Corner(brandIcon.Frame, 8)
	badgeStroke = theme:Stroke(brandIcon.Frame, "Accent", 1)
	badgeStroke.Transparency = 0.55
	self._maid:Give(theme:Watch(function(t)
		if brandIcon.Kind ~= "image" then
			brandIcon:Paint(t.Colors.Accent)
		end
	end))
	styleBrand()
	self._brandIcon = brandIcon

	local brandText = Create.new("Frame", {
		Name = "BrandText",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 58, 0, 0),
		Size = UDim2.new(1, -66, 1, 0),
		Parent = brand,
	})
	local titleLabel = Create.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 0, 0, 14),
		Size = UDim2.new(1, 0, 0, 20),
		Text = cfg.Title,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = brandText,
	})
	if cfg.BrandGradient == false then
		theme:Text(titleLabel, "Text", "Bold", "Header")
	else

		titleLabel.TextColor3 = Color3.new(1, 1, 1)
		theme:Bind(titleLabel, {
			Font = function(t)
				return t.Font.Bold
			end,
			TextSize = function(t)
				return t.TextSize.Header + 3
			end,
		})
		local titleGradient = Create.new("UIGradient", { Parent = titleLabel })
		theme:Bind(titleGradient, {
			Color = function(t)
				return ColorSequence.new(t.Colors.Text, t.Colors.Accent)
			end,
		})
	end
	local subtitleLabel = Create.new("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, 16),
		Text = cfg.Subtitle or "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = brandText,
	})
	theme:Text(subtitleLabel, "TextMuted", "Regular", "Small")

	self._brandText, self._brandTitle, self._brandSubtitle = brandText, titleLabel, subtitleLabel

	local footerCfg = cfg.Footer
	if type(footerCfg) == "string" then
		footerCfg = { Text = footerCfg }
	end
	if footerCfg then
		Validate.check("CreateWindow Footer", footerCfg, { Text = "string", Subtext = "string", Avatar = "boolean" })
	end
	local showKey = cfg.ToggleKey ~= nil and not touch
	local footerH = 0
	if footerCfg or showKey then
		footerH = (footerCfg and footerCfg.Avatar) and 58 or 38
		local footer = Create.new("Frame", {
			Name = "Footer",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, footerH),
			Parent = sidebar,
		})
		local footerLine = Create.new("Frame", { Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 0), Parent = footer })
		theme:Bind(footerLine, { BackgroundColor3 = "Divider" })

		local textX = 14
		local player = Services.Players and Services.Players.LocalPlayer
		if footerCfg and footerCfg.Avatar then
			local avatar = Create.new("ImageLabel", {
				Name = "Avatar",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 1),
				Size = UDim2.fromOffset(34, 34),
				BackgroundTransparency = 0,
				Parent = footer,
			})
			Create.Corner(avatar, UDim.new(1, 0))
			theme:Bind(avatar, { BackgroundColor3 = "Control" })
			textX = 54
			if player then
				task.spawn(function()
					local ok, image = pcall(function()
						return Services.Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
					end)
					if ok and avatar.Parent then
						avatar.Image = image
					end
				end)
			end
		end

		local reserve = textX + (showKey and 76 or 12)
		if footerCfg then
			local text = footerCfg.Text
			if text == nil and footerCfg.Avatar and player then
				text = player.DisplayName
			end
			local hasSub = footerCfg.Subtext ~= nil
			local plain = not footerCfg.Avatar and not hasSub
			if text then
				local label = Create.new("TextLabel", {
					Name = "Text",
					Position = hasSub and UDim2.new(0, textX, 0.5, -16) or UDim2.new(0, textX, 0, 1),
					Size = hasSub and UDim2.new(1, -reserve, 0, 16) or UDim2.new(1, -reserve, 1, -1),
					Text = text,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = footer,
				})
				theme:Text(label, plain and "TextMuted" or "Text", plain and "Regular" or "Medium", plain and "Small" or "Body")
			end
			if hasSub then
				local sub = Create.new("TextLabel", {
					Name = "Subtext",
					Position = UDim2.new(0, textX, 0.5, 1),
					Size = UDim2.new(1, -reserve, 0, 14),
					Text = footerCfg.Subtext,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = footer,
				})
				theme:Text(sub, "TextMuted", "Regular", "Small")
			end
		end

		if showKey then
			local badge = Create.new("Frame", {
				Name = "KeyHint",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 1),
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				Parent = footer,
			})
			theme:Bind(badge, { BackgroundColor3 = "Control" })
			theme:Corner(badge, 6)
			theme:Stroke(badge, "Stroke", 1)
			local keyLabel = Create.new("TextLabel", {
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = cfg.ToggleKey.Name,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = badge,
			})
			Create.Padding(keyLabel, 8, 0, 8, 0)
			theme:Text(keyLabel, "TextDim", "Medium", "Small")
			self._keyBadge = keyLabel
		end
		self._footer = footer
	end

	local tabList = Create.new("ScrollingFrame", {
		Name = "Tabs",
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 1, -(64 + footerH)),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = sidebar,
	})
	theme:Bind(tabList, { ScrollBarImageColor3 = "TextMuted" })
	Create.Padding(tabList, 8, 4, 8, 8)
	Create.List(tabList, Enum.FillDirection.Vertical, 6)
	self._tabList = tabList

	local content = Create.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, sp.Sidebar, 0, 0),
		Size = UDim2.new(1, -sp.Sidebar, 1, 0),
		Parent = main,
	})
	self._content = content

	local topbar = Create.new("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, sp.TopBar),
		Parent = content,
	})
	local topLine = Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = topbar,
	})
	theme:Bind(topLine, { BackgroundColor3 = "Divider" })
	Effects.accentLine(self, topbar, Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), UDim2.new(0.6, 0, 0, 1))

	local hamburger = Create.new("TextButton", {
		Name = "SidebarToggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Parent = topbar,
	})
	theme:Corner(hamburger, "Control")
	local bars = {}
	for i = 1, 3 do
		local bar = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (i - 2) * 5),
			Size = UDim2.fromOffset(14, 2),
			Parent = hamburger,
		})
		Create.Corner(bar, UDim.new(1, 0))
		bars[i] = bar
	end
	self._maid:Give(theme:Watch(function(t)
		hamburger.BackgroundColor3 = t.Colors.ControlHover
		hamburger.BackgroundTransparency = 1
		for _, bar in ipairs(bars) do
			bar.BackgroundColor3 = t.Colors.TextDim
		end
	end))
	self._hamburger = hamburger

	local pageTitle = Create.new("TextLabel", {
		Name = "PageTitle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.new(1, -250, 1, 0),
		Text = "",
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = topbar,
	})
	pageTitle.AnchorPoint = Vector2.new(0, 0.5)
	pageTitle.Position = UDim2.new(0, 48, 0.5, 0)
	theme:Text(pageTitle, "Text", "Bold", "Title")
	self._pageTitle = pageTitle
	self._maid:Give(theme:Watch(function()
		self:_updateTitle()
	end))

	local actions = Create.new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = topbar,
	})
	local actionsList = Create.List(actions, Enum.FillDirection.Horizontal, 6)
	actionsList.VerticalAlignment = Enum.VerticalAlignment.Center

	local searchWrap = Create.new("Frame", {
		Name = "Search",
		Size = UDim2.fromOffset(176, 30),
		LayoutOrder = 1,
		Parent = actions,
	})
	theme:Bind(searchWrap, { BackgroundColor3 = "Control" })
	theme:Corner(searchWrap, "Control")

	local magnifier = Create.new("Frame", {
		Name = "Magnifier",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Parent = searchWrap,
	})
	local ring = Create.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(9, 9), Parent = magnifier })
	Create.Corner(ring, UDim.new(1, 0))
	theme:Stroke(ring, "TextMuted", 1.5)
	local handle = Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(11, 11),
		Size = UDim2.fromOffset(5, 2),
		Rotation = 45,
		Parent = magnifier,
	})
	theme:Bind(handle, { BackgroundColor3 = "TextMuted" })
	local searchBox = Create.new("TextBox", {
		Name = "Input",
		Position = UDim2.new(0, 30, 0, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Text = "",
		PlaceholderText = "Search...",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = searchWrap,
	})
	theme:Text(searchBox, "Text", "Regular", "Body")
	theme:Bind(searchBox, { PlaceholderColor3 = "TextMuted" })
	self._searchWrap, self._searchBox = searchWrap, searchBox

	local minimizeButton = topButton(self, actions, MINIMIZE, "Text")
	minimizeButton.Name = "Minimize"
	minimizeButton.LayoutOrder = 2
	local closeButton = topButton(self, actions, CLOSE, "Danger")
	closeButton.Name = "Close"
	closeButton.LayoutOrder = 3

	local pages = Create.new("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.new(0, 0, 0, sp.TopBar),
		Size = UDim2.new(1, 0, 1, -sp.TopBar),
		Parent = content,
	})
	self.Pages = pages

	local gripSize = touch and 30 or 22
	local grip = Create.new("TextButton", {
		Name = "ResizeGrip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		Size = UDim2.fromOffset(gripSize, gripSize),
		ZIndex = 10,
		Visible = cfg.Resizable ~= false,
		Parent = main,
	})
	for i = 1, 2 do
		local line = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, i == 1 and -8 or -6, 1, i == 1 and -8 or -6),
			Size = UDim2.fromOffset(i == 1 and 12 or 6, 1),
			Rotation = -45,
			ZIndex = 10,
			Parent = grip,
		})
		theme:Bind(line, { BackgroundColor3 = "TextMuted" })
	end

	self._cfg, self._touch = cfg, touch
	self:_buildDock(self:_resolveDockMode(cfg.MinimizeStyle or "Auto"))

	self._overlay = Create.new("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = root,
	})
	self._toasts = Toast.new(self, cfg.NotifyPosition)

	local dragStart
	local function startDrag()
		dragStart = self._pos
	end
	local function moveDrag(delta)
		if dragStart then
			self._pos = dragStart + delta / self._uiScale
			self:_place()
		end
	end
	Drag.bind(topbar, { OnStart = startDrag, OnDelta = moveDrag }, self._maid)
	Drag.bind(brand, { OnStart = startDrag, OnDelta = moveDrag }, self._maid)

	local resizeStart
	Drag.bind(grip, {
		OnStart = function()
			resizeStart = Vector2.new(self._curW, self._curH)
			self._resizing = true
		end,
		OnDelta = function(delta)
			if resizeStart then
				self._size = resizeStart + delta / self._uiScale
				self:_queueLayout()
			end
		end,
		OnEnd = function()
			self._resizing = false
			self._size = Vector2.new(self._curW, self._curH)
		end,
	}, self._maid)

	self._maid:Give(minimizeButton.Activated:Connect(function()
		self:Minimize()
	end))
	self._maid:Give(closeButton.Activated:Connect(function()
		self:Destroy()
	end))
	self._maid:Give(hamburger.Activated:Connect(function()
		self:SetSidebarCollapsed(not self._userRail)
	end))
	-- filter after a short pause in typing, not on every keystroke
	local searchToken = 0
	self._maid:Give(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchToken = searchToken + 1
		local token = searchToken
		local text = searchBox.Text
		if text == "" then
			self:_filter("")
			return
		end
		task.delay(0.12, function()
			if token == searchToken and not self._destroyed then
				self:_filter(text)
			end
		end)
	end))
	self._maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_closePopup()
		self:_queueLayout()
	end))
	self._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self._toggleKey then
			return
		end
		if input.KeyCode == self._toggleKey then
			self:Toggle()
		end
	end))

	self:_layout(false)
	self:_placeFab()
	Tween.play(scale, { Scale = 1 }, th.Animation.Normal)
	if cfg.Glow ~= nil then
		self:SetGlow(cfg.Glow)
	end
	return self
end

function Window.new(cfg)
	local partial = {}
	local ok, result = pcall(build, cfg, partial)
	if not ok then
		if partial.self then
			pcall(function()
				partial.self._maid:Destroy()
			end)
		end
		error(result, 0)
	end
	return result
end

function Window:_queueLayout()
	if self._layoutQueued or self._destroyed then
		return
	end
	self._layoutQueued = true
	task.defer(function()
		self._layoutQueued = false
		if self._destroyed then
			return
		end
		self:_layout(false)
		self:_placeFab()
		if self._resizing then
			self._size = Vector2.new(self._curW, self._curH)
		end
	end)
end

function Window:_updateScale()
	local abs = self._gui.AbsoluteSize
	local scale = self._userScale
	if not scale then
		scale = math.clamp(math.min(abs.Y / AUTO_H, abs.X / AUTO_W), AUTO_MIN, 1)
	end
	scale = math.clamp(scale, 0.5, 2)
	self._uiScale = scale
	self._rootScale.Scale = scale
	self._root.Size = UDim2.fromOffset(abs.X / scale, abs.Y / scale)
end

-- Factor between unscaled layout pixels and absolute pixels, or nil while the open/close animation runs
-- (text is re-fitted once the animation settles, instead of every frame).
function Window:_textScale()
	local anim = self._scale.Scale
	if anim < 0.999 then
		return nil
	end
	return math.max(self._uiScale * anim, 0.01)
end

function Window:_viewport()
	return self._gui.AbsoluteSize / self._uiScale
end

function Window:SetScale(scale)
	self._userScale = scale
	self:_layout(false)
	self:_placeFab()
end

function Window:_place()
	local vp = self:_viewport()
	local pos = self._pos
	if not pos then
		return
	end
	local w = self._curW
	local x = math.clamp(pos.X, 100 - w, math.max(vp.X - 100, 100 - w))
	local y = math.clamp(pos.Y, 0, math.max(0, vp.Y - 48))
	self._pos = Vector2.new(x, y)
	self._main.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end

function Window:_layout(animate)
	if self._destroyed then
		return
	end
	local theme = self.Theme:Get()
	local sp = theme.Spacing
	self:_updateScale()
	local vp = self:_viewport()
	if vp.X <= 0 or vp.Y <= 0 then
		return
	end

	local w = math.floor(math.max(MIN_W, math.min(self._size.X, vp.X - EDGE * 2)))
	local h = math.floor(math.max(MIN_H, math.min(self._size.Y, vp.Y - EDGE * 2)))
	self._curW, self._curH = w, h

	local compactBelow = sp.Sidebar + TWO_COLUMN_MIN + 4
	local compact = w < compactBelow
	local rail = compact or self._userRail
	local sidebarW = rail and sp.SidebarRail or sp.Sidebar
	local twoColumns = (w - sidebarW) >= TWO_COLUMN_MIN
	self._compact, self._rail, self._twoCol = compact, rail, twoColumns

	self._main.Size = UDim2.fromOffset(w, h)
	if not self._pos then
		self._pos = Vector2.new((vp.X - w) / 2, (vp.Y - h) / 2)
	end
	self:_place()

	local function apply(inst, props)
		if animate then
			Tween.play(inst, props, theme.Animation.Normal)
		else
			for key, value in pairs(props) do
				inst[key] = value
			end
		end
	end
	apply(self._sidebar, { Size = UDim2.new(0, sidebarW, 1, 0) })
	apply(self._content, {
		Position = UDim2.new(0, sidebarW, 0, 0),
		Size = UDim2.new(1, -sidebarW, 1, 0),
	})

	self._brandText.Visible = not rail
	if rail then
		self._brandIcon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
		self._brandIcon.Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	else
		self._brandIcon.Frame.AnchorPoint = Vector2.new(0, 0.5)
		self._brandIcon.Frame.Position = UDim2.new(0, 14, 0.5, 0)
	end
	if self._footer then
		self._footer.Visible = not rail
	end
	for _, group in pairs(self._groups) do
		if group.Header then
			group.Header.Visible = not rail
		end
	end

	local leftInset = compact and 14 or 48
	self._hamburger.Visible = not compact
	local searchW = 0
	if w >= 400 then
		searchW = w < compactBelow and 120 or 176
	end
	self._searchWrap.Visible = searchW > 0
	self._searchWrap.Size = UDim2.fromOffset(searchW, 30)
	local actionsW = (searchW > 0 and (searchW + 6) or 0) + 66
	self._pageTitle.Position = UDim2.new(0, leftInset, 0.5, 0)
	self._pageTitle.Size = UDim2.new(1, -(leftInset + actionsW + 18), 1, 0)

	for _, tab in ipairs(self._tabs) do
		tab:_setRail(rail)
		tab:_setColumns(twoColumns and 2 or 1)
	end
	if self._toasts then
		self._toasts:_relayout()
	end
end

function Window:_resolveDockMode(style)
	if style ~= "Auto" and style ~= "Pill" and style ~= "Bar" then
		error("[UI] MinimizeStyle must be Auto, Pill or Bar", 0)
	end
	if style == "Auto" then
		return self._touch and "Pill" or "Bar"
	end
	return style
end

function Window:_buildDock(mode)
	local previous = self._dock
	if previous then
		previous.Frame:Destroy()
	end
	self._dock = Dock.new(self, self._cfg, mode)
	if previous then
		self._dock.Pos = previous.Pos
	end
	self._fab, self._fabScale = self._dock.Frame, self._dock.Scale
end

function Window:SetMinimizeStyle(style)
	local mode = self:_resolveDockMode(style)
	if mode == self._dock.Mode then
		return
	end
	self:_buildDock(mode)
	if self._state == "minimized" then
		self._dock:Show()
	end
end

function Window:_placeFab()
	if self._dock and self._dock.Frame.Visible then
		self._dock:Place()
	end
	if self._keylist and self._keylist.Frame.Visible then
		self._keylist:_place()
	end
end

function Window:_transition(state)
	self:_closePopup()
	self._state = state
	if self._keylist then
		self._keylist:_sync()
	end
	self._token = self._token + 1
	local token = self._token
	local anim = self.Theme:Get().Animation

	if state == "open" then
		if self._dock.Mode == "Bar" and self._fab.Visible then
			self._pos = self._dock.Pos
			self:_place()
		end
		self._main.Visible = true
		Tween.play(self._scale, { Scale = 1 }, anim.Normal)
		if self._fab.Visible then
			local tween = Tween.play(self._fabScale, { Scale = 0 }, anim.Fast)
			tween.Completed:Connect(function()
				if self._token == token then
					self._fab.Visible = false
				end
			end)
		end
	else
		local tween = Tween.play(self._scale, { Scale = 0.9 }, anim.Fast)
		tween.Completed:Connect(function()
			if self._token == token then
				self._main.Visible = false
			end
		end)
		if state == "minimized" then
			self._dock:Show()
		elseif self._fab.Visible then
			self._fabScale.Scale = 0
			self._fab.Visible = false
		end
	end
end

function Window:Minimize()
	if self._destroyed or self._state == "minimized" then
		return
	end
	self:_transition("minimized")
end

function Window:Restore()
	if self._destroyed or self._state == "open" then
		return
	end
	self:_transition("open")
end

function Window:Hide()
	if self._destroyed or self._state == "hidden" then
		return
	end
	self:_transition("hidden")
end

function Window:Toggle()
	if self._state == "open" then
		self:Hide()
	else
		self:Restore()
	end
end

function Window:IsOpen()
	return self._state == "open"
end

function Window:IsVisible()
	return self._state == "open"
end

function Window:Show()
	self:Restore()
end

function Window:SetToggleKey(keyCode)
	self._toggleKey = keyCode
	if self._keyBadge then
		self._keyBadge.Text = keyCode and keyCode.Name or "None"
	end
end

function Window:SetSidebarCollapsed(collapsed)
	self._userRail = collapsed and true or false
	self:_layout(true)
end

function Window:_group(name)
	name = name or ""
	local existing = self._groups[name]
	if existing then
		return existing
	end
	self._groupOrder = self._groupOrder + 1
	local theme = self.Theme
	local group = { Name = name, Tabs = {} }

	local frame = Create.new("Frame", {
		Name = "Group_" .. name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = name == "" and 0 or self._groupOrder,
		Parent = self._tabList,
	})
	Create.List(frame, Enum.FillDirection.Vertical, 2)
	group.Frame = frame

	if name ~= "" then
		local header = Create.new("TextButton", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 1,
			Parent = frame,
		})
		local text = Create.new("TextLabel", {
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(1, -36, 1, 0),
			Text = name,
			Parent = header,
		})
		theme:Text(text, "TextDim", "Medium", "Small")
		local chevron = Create.new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			Text = CHEVRON,
			TextXAlignment = Enum.TextXAlignment.Center,
			Rotation = 90,
			Parent = header,
		})
		theme:Text(chevron, "TextMuted", "Bold", "Header")
		group.Header = header
		group.Chevron = chevron
		self._maid:Give(header.Activated:Connect(function()
			group.Items.Visible = not group.Items.Visible
			Tween.play(chevron, { Rotation = group.Items.Visible and 90 or 0 }, theme:Get().Animation.Fast)
		end))
	end

	local items = Create.new("Frame", {
		Name = "Items",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = frame,
	})
	Create.List(items, Enum.FillDirection.Vertical, 2)
	group.Items = items

	self._groups[name] = group
	return group
end

function Window:CreateTab(cfg)
	if self._destroyed then
		error("[UI] CreateTab: this window was destroyed", 0)
	end
	Validate.check("CreateTab", cfg, { Name = "string!", Icon = "string|number|boolean", Group = "string" })
	for _, existing in ipairs(self._tabs) do
		if existing.Name == cfg.Name then
			error(("[UI] CreateTab: a tab named '%s' already exists"):format(cfg.Name), 0)
		end
	end
	local group = self:_group(cfg.Group)
	local tab = Tab.new(self, cfg, group.Items, group)
	group.Tabs[#group.Tabs + 1] = tab
	self._tabs[#self._tabs + 1] = tab
	if not self._current then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	if self._destroyed or self._current == tab then
		return
	end
	self:_closePopup()
	if self._current then
		self._current:_setActive(false)
	end
	self._current = tab
	tab:_setActive(true)
	self:_updateTitle()
end

local function escapeRich(text)
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	return text
end

function Window:_updateTitle()
	local tab = self._current
	if not tab then
		self._pageTitle.Text = ""
		return
	end
	local group = tab._group and tab._group.Name or ""
	if group == "" then
		self._pageTitle.Text = escapeRich(tab.Name)
	else
		local muted = self.Theme:Get().Colors.TextMuted:ToHex()
		self._pageTitle.Text = ('<font color="#%s">%s  \u{203A}  </font>%s'):format(muted, escapeRich(group), escapeRich(tab.Name))
	end
end

function Window:_removeTab(tab)
	for index, existing in ipairs(self._tabs) do
		if existing == tab then
			table.remove(self._tabs, index)
			break
		end
	end
	local group = tab._group
	if group then
		for index, existing in ipairs(group.Tabs) do
			if existing == tab then
				table.remove(group.Tabs, index)
				break
			end
		end
	end
	if self._current == tab then
		self._current = nil
		if self._tabs[1] then
			self:SelectTab(self._tabs[1])
		else
			self:_updateTitle()
		end
	end
end

function Window:_filter(text)
	local query = string.lower(string.match(text or "", "^%s*(.-)%s*$"))
	for _, tab in ipairs(self._tabs) do
		tab:_applyFilter(query)
	end
	for _, group in pairs(self._groups) do
		local any = false
		for _, tab in ipairs(group.Tabs) do
			if tab.Button.Visible then
				any = true
				break
			end
		end
		group.Frame.Visible = any
	end
end

function Window:_closePopup()
	if self._popup then
		self._popup.Close()
	end
end

function Window:Notify(cfg)
	if self._destroyed then
		return nil
	end
	return self._toasts:Push(cfg)
end

function Window:CreateKeybindList(cfg)
	if self._destroyed then
		return nil
	end
	if self._keylist then
		self._keylist:Destroy()
	end
	self._keylist = KeyList.new(self, cfg or {})
	self._keylist:_sync()
	return self._keylist
end

function Window:GetKeybindList()
	return self._keylist
end

function Window:Confirm(cfg)
	if self._destroyed then
		return nil
	end
	return Dialog.open(self, cfg)
end

function Window:SetTitle(text)
	self._brandTitle.Text = tostring(text)
end

function Window:SetSubtitle(text)
	self._brandSubtitle.Text = tostring(text)
end

function Window:SetColor(token, color)
	if typeof(color) ~= "Color3" then
		error("[UI] SetColor expects a Color3", 0)
	end
	if self.Theme:Get().Colors[token] == nil then
		error(("[UI] SetColor: unknown color token '%s'"):format(tostring(token)), 0)
	end
	self.Theme:Patch({ Colors = { [token] = color } })
end

function Window:SetAccent(color)
	self:SetColor("Accent", color)
end

function Window:SetGradient(first, second)
	if typeof(first) ~= "Color3" or typeof(second) ~= "Color3" then
		error("[UI] SetGradient expects two Color3 values", 0)
	end
	self.Theme:Patch({ Colors = { Accent = first, AccentAlt = second } })
end

function Window:SetGlow(strength)
	if type(strength) ~= "number" then
		error("[UI] SetGlow expects a number", 0)
	end
	strength = math.clamp(strength, 0, 3)
	local base = self.Theme._base
	self.Theme:Patch({
		Transparency = {
			Glow = math.clamp(1 - (1 - base.Glow) * strength, 0, 1),
			BrandGlow = math.clamp(1 - (1 - base.BrandGlow) * strength, 0, 1),
		},
	})
end

function Window:SetTheme(spec)
	self.Theme:Set(spec)
end

function Window:_onDestroy(fn)
	self._destroyCallbacks[#self._destroyCallbacks + 1] = fn
end

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._onClose then
		local ok, err = pcall(self._onClose)
		if not ok then
			warn("[UI] OnClose errored: " .. tostring(err))
		end
	end
	for _, fn in ipairs(self._destroyCallbacks) do
		pcall(fn)
	end
	self._maid:Destroy()
end

return Window
end

__defs["providers/luarmor"] = function()
local Validate = require("util/validate")
local Env = require("util/env")

local Luarmor = {}

local SDK_URL = "https://sdkapi-public.luarmor.net/library.lua"

local MESSAGES = {
	KEY_HWID_LOCKED = "This key is locked to another device. Reset it from your key panel.",
	KEY_INCORRECT = "That key is incorrect.",
	KEY_INVALID = "That key is not valid.",
	KEY_EXPIRED = "This key has expired.",
	KEY_BANNED = "This key has been blacklisted.",
	SCRIPT_ID_INCORRECT = "The script id is incorrect.",
	SCRIPT_ID_INVALID = "The script id is not valid.",
	INVALID_EXECUTOR = "This executor is not supported.",
	SECURITY_ERROR = "Security check failed. Try again.",
	TIME_ERROR = "Your system clock is out of sync.",
	UNKNOWN_ERROR = "Unknown error. Try again.",
}

function Luarmor.new(opts)
	Validate.check("Providers.Luarmor", opts, {
		ScriptId = "string!",
		SdkUrl = "string",
		Messages = "table",
	})

	local provider = {}
	local sdk

	local function load()
		if not sdk then
			local library = loadstring(game:HttpGet(opts.SdkUrl or SDK_URL))()
			library.script_id = opts.ScriptId
			sdk = library
		end
		return sdk
	end

	function provider.Validate(key)
		local ok, result = pcall(function()
			return load().check_key(key)
		end)
		if not ok or type(result) ~= "table" then
			return false, "Could not reach the key service. Check your connection."
		end
		if result.code == "KEY_VALID" then
			return true, result.message or "Key accepted.", result.data
		end
		local custom = opts.Messages and opts.Messages[result.code]
		return false, custom or MESSAGES[result.code] or result.message or "That key was not accepted.", result
	end

	function provider.LoadScript(key)
		if type(key) == "string" then
			Env().script_key = key
		end
		return load().load_script()
	end

	return provider
end

return Luarmor
end

__defs["theme/manager"] = function()
local Themes = require("theme/themes")
local Create = require("util/create")

local Manager = {}
Manager.__index = Manager

local function clone(source)
	local out = {}
	for key, value in pairs(source) do
		out[key] = type(value) == "table" and clone(value) or value
	end
	return out
end

local function merge(base, override)
	local out = clone(base)
	for key, value in pairs(override) do
		if type(value) == "table" and type(out[key]) == "table" then
			out[key] = merge(out[key], value)
		else
			out[key] = value
		end
	end
	return out
end

local registry = { Dark = clone(Themes.Dark) }
for name, override in pairs(Themes) do
	if name ~= "Dark" then
		registry[name] = merge(registry.Dark, override)
	end
end

function Manager.Register(name, override)
	if type(name) ~= "string" or type(override) ~= "table" then
		error("[UI] RegisterTheme expects (name: string, overrides: table)", 0)
	end
	registry[name] = merge(registry.Dark, override)
end

function Manager.Names()
	local names = {}
	for name in pairs(registry) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function Manager.new(spec)
	local self = setmetatable({ _watchers = {} }, Manager)
	self:Set(spec or "Mono", true)
	return self
end

function Manager:Get()
	return self._theme
end

function Manager:Name()
	return self._name
end

function Manager:Set(spec, silent)
	local theme, name
	if type(spec) == "string" then
		theme = registry[spec]
		if not theme then
			error(("[UI] unknown theme '%s' (available: %s)"):format(spec, table.concat(Manager.Names(), ", ")), 0)
		end
		name = spec
	elseif type(spec) == "table" then
		theme = merge(registry.Dark, spec)
		name = "Custom"
	else
		error("[UI] theme must be a theme name or a table of overrides", 0)
	end
	self._theme, self._name = theme, name
	self._base = clone(theme.Transparency)
	if not silent then
		self:_notify()
	end
end

function Manager:_notify()
	local list = {}
	for _, fn in pairs(self._watchers) do
		list[#list + 1] = fn
	end
	for _, fn in ipairs(list) do
		local ok, err = pcall(fn, self._theme)
		if not ok then
			warn("[UI] theme watcher error: " .. tostring(err))
		end
	end
end

function Manager:Patch(override)
	self._theme = merge(self._theme, override)
	self:_notify()
end

function Manager:Watch(fn)
	local handle = {}
	self._watchers[handle] = fn
	function handle.Disconnect()
		self._watchers[handle] = nil
	end
	handle.Destroy = handle.Disconnect
	fn(self._theme)
	return handle
end

function Manager:Bind(inst, map)
	local handle = self:Watch(function(theme)
		for prop, source in pairs(map) do
			local value
			if type(source) == "function" then
				value = source(theme)
			else
				value = theme.Colors[source]
				if value == nil then
					warn("[UI] unknown theme token '" .. tostring(source) .. "'")
				end
			end
			if value ~= nil then
				inst[prop] = value
			end
		end
	end)
	inst.Destroying:Connect(function()
		handle.Disconnect()
	end)
	return handle
end

function Manager:Corner(parent, key)
	local corner = Create.new("UICorner", { Parent = parent })
	self:Bind(corner, {
		CornerRadius = function(theme)
			return UDim.new(0, theme.Radius[key])
		end,
	})
	return corner
end

function Manager:Stroke(parent, token, thickness)
	local stroke = Create.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = thickness or 1,
		Parent = parent,
	})
	self:Bind(stroke, { Color = token })
	return stroke
end

function Manager:Text(inst, color, font, size)
	return self:Bind(inst, {
		TextColor3 = color,
		Font = function(theme)
			return theme.Font[font or "Medium"]
		end,
		TextSize = function(theme)
			return theme.TextSize[size or "Body"]
		end,
	})
end

return Manager
end

__defs["theme/themes"] = function()
local function hex(value)
	return Color3.fromHex(value)
end

return {
	Dark = {
		Colors = {
			Window = hex("0E0E10"),
			Sidebar = hex("131316"),
			Card = hex("18181B"),
			Control = hex("232328"),
			ControlHover = hex("2C2C32"),
			ControlPressed = hex("36363D"),
			Stroke = hex("2A2A30"),
			Divider = hex("26262B"),
			Text = hex("F2F2F4"),
			TextDim = hex("A1A1AA"),
			TextMuted = hex("6B6B74"),
			Accent = hex("FF7A2F"),
			AccentText = hex("FFFFFF"),
			AccentAlt = hex("FF4F8B"),
			Danger = hex("FF5A5A"),
			Success = hex("4CD08B"),
			Warning = hex("FFC24B"),
		},
		Radius = { Window = 12, Card = 10, Control = 8 },
		Spacing = {
			Padding = 12,
			Gap = 8,
			Row = 34,
			RowTouch = 44,
			Header = 40,
			TopBar = 52,
			Sidebar = 196,
			SidebarRail = 60,
		},
		Font = {
			Regular = Enum.Font.Gotham,
			Medium = Enum.Font.GothamMedium,
			Bold = Enum.Font.GothamBold,
		},
		TextSize = { Title = 17, Header = 15, Body = 14, Small = 12 },
		Animation = { Fast = 0.12, Normal = 0.2, Slow = 0.35 },

		Transparency = { Toast = 0.2, Pill = 0.12, Card = 0.04, Glow = 0.9, BrandGlow = 0.82 },
	},

	Mono = {
		Colors = {
			Window = hex("0A0A0A"),
			Sidebar = hex("0F0F0F"),
			Card = hex("141414"),
			Control = hex("1F1F1F"),
			ControlHover = hex("2A2A2A"),
			ControlPressed = hex("353535"),
			Stroke = hex("2A2A2A"),
			Divider = hex("232323"),
			Text = hex("F5F5F5"),
			TextDim = hex("A3A3A3"),
			TextMuted = hex("666666"),
			Accent = hex("F5F5F5"),
			AccentAlt = hex("8C8C8C"),
			AccentText = hex("0A0A0A"),
			Danger = hex("E5E5E5"),
			Success = hex("D4D4D4"),
			Warning = hex("BDBDBD"),
		},
		Transparency = { Glow = 0.95, BrandGlow = 0.93 },
	},

	Ocean = {
		Colors = { Accent = hex("3B9BFF"), AccentAlt = hex("A855F7") },
	},
}
end

__defs["util/create"] = function()
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
end

__defs["util/drag"] = function()
local UserInputService = require("util/services").UserInputService

local Drag = {}

function Drag.bind(handle, opts, maid)
	local threshold = opts.Threshold or 0
	local session

	local function stop()
		if session then
			session.changed:Disconnect()
			session.ended:Disconnect()
			session = nil
		end
	end
	maid:Give(stop)

	maid:Give(handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		stop()

		local start = Vector2.new(input.Position.X, input.Position.Y)
		local moved = false
		if opts.OnStart then
			opts.OnStart(input)
		end

		local changed = UserInputService.InputChanged:Connect(function(current)
			if current ~= input and current.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local delta = Vector2.new(current.Position.X, current.Position.Y) - start
			if not moved and delta.Magnitude >= threshold then
				moved = true
			end
			if moved and opts.OnDelta then
				opts.OnDelta(delta)
			end
		end)

		local ended = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				stop()
				if opts.OnEnd then
					opts.OnEnd(moved)
				end
			end
		end)

		session = { changed = changed, ended = ended }
	end))
end

return Drag
end

__defs["util/env"] = function()
return function()
	local ok, value = pcall(function()
		return getgenv()
	end)
	if ok and type(value) == "table" then
		return value
	end
	return _G
end
end

__defs["util/fit"] = function()
-- Text measuring and wrapping. Instead of cutting text off with "...",
-- labels wrap onto extra lines and their row grows to fit them.
local TextService = require("util/services").TextService

local Fit = {}

local HUGE = 100000
local cache = {}
local cacheSize = 0

local function measure(text, size, font, width)
	local key = text .. "\0" .. tostring(size) .. "\0" .. tostring(font) .. "\0" .. tostring(width)
	local hit = cache[key]
	if hit then
		return hit
	end
	if not TextService then
		return nil
	end
	local ok, result = pcall(TextService.GetTextSize, TextService, text, size, font, Vector2.new(width, HUGE))
	if not ok then
		return nil
	end
	if cacheSize >= 512 then
		cache, cacheSize = {}, 0
	end
	cache[key] = result
	cacheSize = cacheSize + 1
	return result
end

-- Width of `text` on one line, in unscaled pixels.
function Fit.width(text, size, font)
	local bounds = measure(text, size, font, HUGE)
	return bounds and math.ceil(bounds.X) or #text * size * 0.55
end

-- Height of `text` when wrapped to `width` unscaled pixels.
function Fit.height(text, size, font, width)
	local bounds = measure(text, size, font, math.max(math.floor(width), 1))
	return bounds and math.ceil(bounds.Y) or size
end

-- Keeps `container` tall enough for `label` to wrap its text onto several lines.
-- A single line keeps the container at `base` height; every extra line adds its height on top.
-- opts:
--   label, container, base, maid
--   scale()      returns the current unscaled-to-absolute factor, or nil while the window animates
--   reserve      pixels kept free next to the label (number, or function(width) -> number)
--   padX         horizontal padding inside the label
--   sizeLabel    set the label width to the container width minus `reserve`
--   watch        extra TextLabels whose text affects `reserve`
function Fit.bind(opts)
	local label, container = opts.label, opts.container
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None

	local lastKey
	local queued = false

	local function refit()
		queued = false
		if not label.Parent or not container.Parent then
			return
		end
		local scale = opts.scale()
		if not scale then
			return
		end
		local width = math.floor(container.AbsoluteSize.X / scale + 0.5)
		if width <= 0 then
			return
		end
		local reserve = opts.reserve or 0
		if type(reserve) == "function" then
			reserve = reserve(width)
		end
		local avail = math.max(width - reserve - (opts.padX or 0), 1)
		local text, size, font = label.Text, label.TextSize, label.Font
		local key = table.concat({ text, tostring(size), tostring(font), tostring(avail), tostring(reserve) }, "\0")
		if key == lastKey then
			return
		end
		lastKey = key
		if opts.sizeLabel then
			label.Size = UDim2.new(1, -reserve, label.Size.Y.Scale, label.Size.Y.Offset)
		end
		local line = Fit.height("Ag", size, font, HUGE)
		local height = Fit.height(text ~= "" and text or "Ag", size, font, avail)
		local extra = math.max(height - line, 0)
		local current = container.Size
		local target = opts.base + extra
		if current.Y.Offset ~= target or current.Y.Scale ~= 0 then
			container.Size = UDim2.new(current.X.Scale, current.X.Offset, 0, target)
		end
	end

	local function queue()
		if queued then
			return
		end
		queued = true
		task.defer(refit)
	end

	local maid = opts.maid
	maid:Give(container:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue))
	for _, prop in ipairs({ "Text", "TextSize", "Font" }) do
		maid:Give(label:GetPropertyChangedSignal(prop):Connect(queue))
	end
	for _, other in ipairs(opts.watch or {}) do
		maid:Give(other:GetPropertyChangedSignal("Text"):Connect(queue))
		maid:Give(other:GetPropertyChangedSignal("TextSize"):Connect(queue))
	end
	queue()

	return {
		Refit = function()
			lastKey = nil
			queue()
		end,
	}
end

return Fit
end

__defs["util/glyphs"] = function()
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
end

__defs["util/maid"] = function()
local Maid = {}
Maid.__index = Maid

local function release(item)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "table" then
		if type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

function Maid.new()
	return setmetatable({ _items = {}, _dead = false }, Maid)
end

function Maid:Give(item)
	if self._dead then
		pcall(release, item)
		return item
	end
	self._items[#self._items + 1] = item
	return item
end

function Maid:Clean()
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(release, items[i])
		if not ok then
			warn("[UI] cleanup error: " .. tostring(err))
		end
	end
end

function Maid:Destroy()
	self._dead = true
	self:Clean()
end

return Maid
end

__defs["util/mount"] = function()
local Services = require("util/services")

local Mount = {}

function Mount.gui(gui)
	local candidates = {
		function()
			return gethui and gethui()
		end,
		function()
			return Services.CoreGui
		end,
		function()
			local player = Services.Players and Services.Players.LocalPlayer
			return player and player:FindFirstChildOfClass("PlayerGui")
		end,
	}
	for _, get in ipairs(candidates) do
		local ok, parent = pcall(get)
		if ok and parent then
			local assigned = pcall(function()
				gui.Parent = parent
			end)
			if assigned and gui.Parent == parent then
				return parent
			end
		end
	end
	error("[UI] could not find a place to parent the interface (gethui, CoreGui and PlayerGui all failed)", 0)
end

return Mount
end

__defs["util/pointer"] = function()
local Services = require("util/services")
local UserInputService = Services.UserInputService
local GuiService = Services.GuiService

local Pointer = {}

function Pointer.toScreen(position)
	local inset = 0
	if GuiService then
		local ok, value = pcall(function()
			return GuiService:GetGuiInset()
		end)
		if ok and value then
			inset = value.Y
		end
	end
	return Vector2.new(position.X, position.Y + inset)
end

function Pointer.bind(handle, opts, maid)
	local session

	local function stop()
		if session then
			session.changed:Disconnect()
			session.ended:Disconnect()
			session = nil
		end
	end
	maid:Give(stop)

	maid:Give(handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		stop()
		if opts.OnBegin then
			opts.OnBegin()
		end
		opts.OnMove(Pointer.toScreen(input.Position))

		local changed = UserInputService.InputChanged:Connect(function(current)
			if current ~= input and current.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			opts.OnMove(Pointer.toScreen(current.Position))
		end)
		local ended = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				stop()
				if opts.OnEnd then
					opts.OnEnd()
				end
			end
		end)
		session = { changed = changed, ended = ended }
	end))
end

return Pointer
end

__defs["util/services"] = function()
local function get(name)
	local ok, service = pcall(game.GetService, game, name)
	return ok and service or nil
end

return {
	Players = get("Players"),
	UserInputService = get("UserInputService"),
	TweenService = get("TweenService"),
	RunService = get("RunService"),
	CoreGui = get("CoreGui"),
	Workspace = get("Workspace"),
	GuiService = get("GuiService"),
	TextService = get("TextService"),
}
end

__defs["util/tween"] = function()
local TweenService = require("util/services").TweenService

local Tween = {}
local active = setmetatable({}, { __mode = "k" })

local STYLE = Enum.EasingStyle.Quad
local DIRECTION = Enum.EasingDirection.Out

function Tween.play(inst, props, duration, style, direction)
	local keys = {}
	for key in pairs(props) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local id = table.concat(keys, ",")

	local byInst = active[inst]
	if not byInst then
		byInst = {}
		active[inst] = byInst
	end
	local previous = byInst[id]
	if previous then
		previous:Cancel()
	end

	local info = TweenInfo.new(duration or 0.18, style or STYLE, direction or DIRECTION)
	local tween = TweenService:Create(inst, info, props)
	byInst[id] = tween
	tween.Completed:Connect(function()
		if byInst[id] == tween then
			byInst[id] = nil
		end
	end)
	tween:Play()
	return tween
end

return Tween
end

__defs["util/validate"] = function()
local Validate = {}

function Validate.check(where, cfg, schema)
	if type(cfg) ~= "table" then
		error(("[UI] %s: expected a config table, got %s"):format(where, typeof(cfg)), 0)
	end
	for key, spec in pairs(schema) do
		local required = spec:sub(-1) == "!"
		local types = required and spec:sub(1, -2) or spec
		local value = cfg[key]
		if value == nil then
			if required then
				error(("[UI] %s: missing required field '%s' (%s)"):format(where, key, types), 0)
			end
		else
			local matched = false
			for expected in types:gmatch("[^|]+") do
				if typeof(value) == expected then
					matched = true
					break
				end
			end
			if not matched then
				error(("[UI] %s: field '%s' must be %s, got %s"):format(where, key, types, typeof(value)), 0)
			end
		end
	end
	return cfg
end

return Validate
end

__defs["init"] = function()
local Window = require("core/window")
local ThemeManager = require("theme/manager")
local Icons = require("core/icons")
local KeyGate = require("core/keygate")
local Luarmor = require("providers/luarmor")
local Env = require("util/env")

local VERSION = "0.9.0"
local BUILD = "e1a2d54e3015"

local Library = {
	Version = VERSION,
	Build = BUILD,
}

Library.Providers = { Luarmor = Luarmor.new }

local function registry()
	local root = Env()
	root.__RobloxUILib = root.__RobloxUILib or {}
	return root.__RobloxUILib
end

function Library:CreateWindow(cfg)
	local reg = registry()
	local key = type(cfg) == "table" and tostring(cfg.Id or cfg.Title) or nil
	if key and reg[key] then
		pcall(function()
			reg[key]:Destroy()
		end)
		reg[key] = nil
	end
	local window = Window.new(cfg)
	if key then
		reg[key] = window
		window:_onDestroy(function()
			if reg[key] == window then
				reg[key] = nil
			end
		end)
	end
	return window
end

function Library:CreateKeyGate(cfg)
	local reg = registry()
	local key = type(cfg) == "table" and ("gate:" .. tostring(cfg.Title)) or nil
	if key and reg[key] then
		pcall(function()
			reg[key]:Destroy()
		end)
		reg[key] = nil
	end
	local gate = KeyGate.new(cfg)
	if key then
		reg[key] = gate
		gate:_onDestroy(function()
			if reg[key] == gate then
				reg[key] = nil
			end
		end)
	end
	return gate
end

function Library:CheckVersion(expected)
	local wanted = tonumber(string.match(tostring(expected), "^(%d+)"))
	local mine = tonumber(string.match(VERSION, "^(%d+)"))
	return wanted ~= nil and mine ~= nil and wanted == mine
end

function Library:RegisterTheme(name, overrides)
	ThemeManager.Register(name, overrides)
end

function Library:RegisterIcons(map)
	if type(map) ~= "table" then
		error("[UI] RegisterIcons expects a table of name = assetId", 0)
	end
	for name, id in pairs(map) do
		Icons.Register(name, id)
	end
end

function Library:DestroyAll()
	local reg = registry()
	for key, window in pairs(reg) do
		pcall(function()
			window:Destroy()
		end)
		reg[key] = nil
	end
end

return Library
end

return require("init")
