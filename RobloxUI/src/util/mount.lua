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
