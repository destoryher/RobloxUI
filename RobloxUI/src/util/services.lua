local function get(name)
	local ok, service = pcall(game.GetService, game, name)
	return ok and service or nil
end

return {
	Players = get("Players"),
	UserInputService = get("UserInputService"),
	TweenService = get("TweenService"),
	RunService = get("RunService"),
	CoreGui = get("CoreGui"),
	Workspace = get("Workspace"),
	GuiService = get("GuiService"),
}
