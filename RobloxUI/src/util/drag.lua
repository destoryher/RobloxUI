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
