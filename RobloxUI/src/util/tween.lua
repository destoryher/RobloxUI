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
