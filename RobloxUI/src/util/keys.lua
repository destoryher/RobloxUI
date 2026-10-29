-- Shared key handling for keybinds and the keybind list.
-- A bind is either an Enum.KeyCode (keyboard or gamepad) or an Enum.UserInputType mouse button.
local Keys = {}

local function enumItem(enum, name)
	local ok, item = pcall(function()
		return enum[name]
	end)
	if ok and typeof(item) == "EnumItem" then
		return item
	end
	return nil
end

-- Mouse buttons the running Roblox build actually exposes. Side buttons are picked up
-- automatically if the engine ever reports them.
local MOUSE = {}
for _, name in ipairs({ "MouseButton1", "MouseButton2", "MouseButton3", "MouseButton4", "MouseButton5" }) do
	local item = enumItem(Enum.UserInputType, name)
	if item then
		MOUSE[name] = item
	end
end
Keys.Mouse = MOUSE

local ALIASES = {
	LMB = "MouseButton1",
	LeftClick = "MouseButton1",
	Mouse1 = "MouseButton1",
	RMB = "MouseButton2",
	RightClick = "MouseButton2",
	Mouse2 = "MouseButton2",
	MMB = "MouseButton3",
	MiddleClick = "MouseButton3",
	Mouse3 = "MouseButton3",
	Mouse4 = "MouseButton4",
	Mouse5 = "MouseButton5",
}

local SHORT = {
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	MouseButton3 = "MMB",
	MouseButton4 = "Mouse4",
	MouseButton5 = "Mouse5",
	LeftShift = "LShift",
	RightShift = "RShift",
	LeftControl = "LCtrl",
	RightControl = "RCtrl",
	LeftAlt = "LAlt",
	RightAlt = "RAlt",
	LeftSuper = "LWin",
	RightSuper = "RWin",
	Backspace = "Bksp",
	Return = "Enter",
	PageUp = "PgUp",
	PageDown = "PgDn",
	CapsLock = "Caps",
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
	KeypadZero = "Num0",
	KeypadOne = "Num1",
	KeypadTwo = "Num2",
	KeypadThree = "Num3",
	KeypadFour = "Num4",
	KeypadFive = "Num5",
	KeypadSix = "Num6",
	KeypadSeven = "Num7",
	KeypadEight = "Num8",
	KeypadNine = "Num9",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonL3 = "LS",
	ButtonR3 = "RS",
}

function Keys.isMouse(key)
	return key ~= nil and key.EnumType == Enum.UserInputType
end

-- Accepts an Enum.KeyCode, a mouse Enum.UserInputType, or a name such as "F", "MouseButton2", "RMB" or "RightClick".
-- Returns the EnumItem, or nil for nil / "" / unknown names (unless `strict`, which errors).
function Keys.parse(value, where, strict)
	if value == nil or value == "" then
		return nil
	end
	if typeof(value) == "EnumItem" then
		if value.EnumType == Enum.KeyCode then
			return value
		end
		if value.EnumType == Enum.UserInputType and MOUSE[value.Name] then
			return value
		end
	elseif type(value) == "string" then
		local name = ALIASES[value] or value
		if MOUSE[name] then
			return MOUSE[name]
		end
		local key = enumItem(Enum.KeyCode, name)
		if key and key ~= Enum.KeyCode.Unknown then
			return key
		end
	end
	if strict then
		error(("[UI] %s: expected an Enum.KeyCode, a mouse button, or a key name like \"F\" or \"MouseButton2\""):format(where or "Keybind"), 0)
	end
	return nil
end

function Keys.text(key, empty)
	if not key then
		return empty or "None"
	end
	return SHORT[key.Name] or key.Name
end

-- The bind an input represents, or nil if it is not bindable (mouse movement, touch, scroll...).
function Keys.fromInput(input)
	local kind = input.UserInputType
	if MOUSE[kind.Name] == kind then
		return kind
	end
	if kind == Enum.UserInputType.Keyboard or string.sub(kind.Name, 1, 7) == "Gamepad" then
		if input.KeyCode ~= Enum.KeyCode.Unknown then
			return input.KeyCode
		end
	end
	return nil
end

-- While any keybind is waiting for a key, presses must not also trigger other binds or the menu key.
local capturing, captured = 0, nil

function Keys.beginCapture()
	capturing = capturing + 1
end

function Keys.endCapture(input)
	capturing = math.max(capturing - 1, 0)
	if input then
		captured = input
	end
end

function Keys.blocked(input)
	return capturing > 0 or (input ~= nil and input == captured)
end

function Keys.matches(input, key)
	if not key then
		return false
	end
	if Keys.isMouse(key) then
		return input.UserInputType == key
	end
	return input.KeyCode == key
end

return Keys
