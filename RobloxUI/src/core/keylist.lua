local Create = require("util/create")
local Tween = require("util/tween")
local Drag = require("util/drag")
local Maid = require("util/maid")
local Validate = require("util/validate")
local Keys = require("util/keys")

local KeyList = {}
KeyList.__index = KeyList

local Entry = {}
Entry.__index = Entry

local DEFAULT_WIDTH = 210
local COLOR_TOKENS = { Accent = true, Success = true, Warning = true, Danger = true, AccentAlt = true }

local SHOW_WHEN = { Minimized = true, Hidden = true, Closed = true, Always = true }

local function toKey(value)
	return Keys.parse(value, "KeybindList", true)
end

local function keyText(key)
	return Keys.text(key, "--")
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
