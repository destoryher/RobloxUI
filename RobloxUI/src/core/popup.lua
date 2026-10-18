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
