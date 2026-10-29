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
