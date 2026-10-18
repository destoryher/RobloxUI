local Create = require("util/create")
local Tween = require("util/tween")
local Validate = require("util/validate")
local PushButton = require("core/pushbutton")

local Dialog = {}

function Dialog.open(window, cfg)
	Validate.check("Confirm", cfg, {
		Title = "string",
		Content = "string",
		ConfirmText = "string",
		CancelText = "string",
		Danger = "boolean",
		OnConfirm = "function",
		OnCancel = "function",
	})
	if cfg.Title == nil and cfg.Content == nil then
		error("[UI] Confirm: needs a Title or Content", 0)
	end
	window:_closePopup()
	if window._dialog then
		window._dialog.Close(false)
	end

	local theme = window.Theme
	local anim = theme:Get().Animation
	local vp = window:_viewport()
	local closed = false
	local obj = {}

	local dim = Create.new("TextButton", {
		Name = "ConfirmDim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 60,
		Parent = window._overlay,
	})
	local card = Create.new("Frame", {
		Name = "Dialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, math.min(360, vp.X - 32), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Parent = dim,
	})
	theme:Bind(card, { BackgroundColor3 = "Card" })
	theme:Corner(card, "Window")
	theme:Stroke(card, "Stroke", 1)
	local scale = Create.new("UIScale", { Scale = 0.92, Parent = card })
	Create.Padding(card, 18, 18, 18, 16)
	Create.List(card, Enum.FillDirection.Vertical, 8)

	if cfg.Title then
		local title = Create.new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = cfg.Title,
			TextWrapped = true,
			LayoutOrder = 1,
			Parent = card,
		})
		theme:Text(title, "Text", "Bold", "Title")
	end
	if cfg.Content then
		local content = Create.new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = cfg.Content,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
			Parent = card,
		})
		theme:Text(content, "TextDim", "Regular", "Body")
	end
	local row = Create.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, window._ctx.RowHeight),
		LayoutOrder = 3,
		Parent = card,
	})
	local list = Create.List(row, Enum.FillDirection.Horizontal, 8)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	function obj.Close(confirmed)
		if closed then
			return
		end
		closed = true
		if window._dialog == obj then
			window._dialog = nil
		end
		Tween.play(dim, { BackgroundTransparency = 1 }, anim.Fast)
		local tween = Tween.play(scale, { Scale = 0.92 }, anim.Fast)
		tween.Completed:Connect(function()
			dim:Destroy()
		end)
		dim.Active = false
		local callback = confirmed and cfg.OnConfirm or (confirmed == false and cfg.OnCancel or nil)
		if callback then
			task.spawn(function()
				local ok, err = pcall(callback)
				if not ok then
					warn("[UI] Confirm callback errored: " .. tostring(err))
				end
			end)
		end
	end

	local cancel = PushButton.new(window.Theme, row, cfg.CancelText or "Cancel", "Default", 1, UDim2.new(0.5, -4, 1, 0))
	local confirm = PushButton.new(window.Theme, row, cfg.ConfirmText or "Confirm", cfg.Danger and "Danger" or "Accent", 2, UDim2.new(0.5, -4, 1, 0))
	cancel.Activated:Connect(function()
		obj.Close(false)
	end)
	confirm.Activated:Connect(function()
		obj.Close(true)
	end)
	dim.Activated:Connect(function()
		obj.Close(false)
	end)

	window._dialog = obj
	Tween.play(dim, { BackgroundTransparency = 0.45 }, anim.Normal)
	Tween.play(scale, { Scale = 1 }, anim.Normal)
	return obj
end

return Dialog
