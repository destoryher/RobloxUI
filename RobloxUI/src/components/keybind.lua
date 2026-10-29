local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Services = require("util/services")
local Keys = require("util/keys")

local UserInputService = Services.UserInputService

local Keybind = setmetatable({}, { __index = Control })
Keybind.__index = Keybind

function Keybind.new(card, cfg)
	Validate.check("CreateKeybind", cfg, {
		Name = "string!",
		Default = "EnumItem|string",
		Callback = "function",
		Pressed = "function",
		Released = "function",
		AllowMouse = "boolean",
		Description = "string",
		Disabled = "boolean",
	})
	local self = Control.base(card, cfg, "Keybind", Keybind)
	local theme = self._ctx.Theme
	self._key = Keys.parse(cfg.Default, "CreateKeybind", true)
	self._listening = false
	self._held = false
	self._allowMouse = cfg.AllowMouse ~= false
	self._pressed = cfg.Pressed
	self._released = cfg.Released
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
		self:_setListening(not self._listening)
	end))
	self._maid:Give(function()
		self:_setListening(false)
	end)

	self._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if self._listening then
			self:_capture(input, processed)
			return
		end
		if processed or self._disabled or not self._key or Keys.blocked(input) then
			return
		end
		if Keys.matches(input, self._key) then
			self._held = true
			self:_call(self._pressed, "Pressed")
		end
	end))

	self._maid:Give(UserInputService.InputEnded:Connect(function(input)
		if self._held and Keys.matches(input, self._key) then
			self._held = false
			self:_call(self._released, "Released")
		end
	end))

	self:_onRender(function(t)
		local c = t.Colors
		button.BackgroundColor3 = self._listening and c.ControlHover or c.Control
		button.BackgroundTransparency = self._disabled and 0.4 or 0
		button.TextColor3 = self._listening and c.Accent or (self._key and c.Text or c.TextMuted)
		button.Text = self._listening and "..." or Keys.text(self._key)
		stroke.Color = self._listening and c.Accent or c.Stroke
	end)

	return self:_finish(cfg)
end

function Keybind:_setListening(listening, input)
	listening = listening and true or false
	if listening == self._listening then
		return
	end
	self._listening = listening
	if listening then
		Keys.beginCapture()
	else
		Keys.endCapture(input)
	end
	if not self._destroyed then
		self:_rerender(true)
	end
end

-- While listening: Escape cancels, Backspace/Delete clears, any other key or mouse button binds.
-- Mouse clicks on the menu itself are ignored so you can click away; click in the game to bind one.
function Keybind:_capture(input, processed)
	local key = Keys.fromInput(input)
	if not key then
		return
	end
	if Keys.isMouse(key) and (processed or not self._allowMouse) then
		return
	end
	self:_setListening(false, input)
	if key == Enum.KeyCode.Backspace or key == Enum.KeyCode.Delete then
		self:Set(nil)
	elseif key ~= Enum.KeyCode.Escape then
		self:Set(key)
	end
end

function Keybind:_call(fn, label)
	if not fn then
		return
	end
	task.spawn(function()
		local ok, err = pcall(fn)
		if not ok then
			warn(("[UI] %s callback for '%s' errored: %s"):format(label, self._name, tostring(err)))
		end
	end)
end

function Keybind:Get()
	return self._key
end

-- The bind as a string for configs ("F", "MouseButton2"), or "" when unbound. Set() accepts it back.
function Keybind:GetKeyName()
	return self._key and self._key.Name or ""
end

function Keybind:IsHeld()
	return self._held
end

function Keybind:Set(key, silent)
	key = Keys.parse(key, "Keybind:Set")
	if key == self._key then
		return
	end
	if self._held then
		self._held = false
		self:_call(self._released, "Released")
	end
	self._key = key
	self:_rerender(true)
	if not silent then
		self:_fire(key)
	end
	self:_emit(key)
end

return Keybind
