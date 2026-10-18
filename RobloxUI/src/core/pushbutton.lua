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
