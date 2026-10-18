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
