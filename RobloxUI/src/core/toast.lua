local Create = require("util/create")
local Tween = require("util/tween")
local Validate = require("util/validate")

local Toast = {}
Toast.__index = Toast

local TYPES = { Info = "Accent", Success = "Success", Warning = "Warning", Error = "Danger" }
local POSITIONS = {
	TopRight = { x = 1, y = 0 },
	BottomRight = { x = 1, y = 1 },
	TopLeft = { x = 0, y = 0 },
	BottomLeft = { x = 0, y = 1 },
}
local MAX_VISIBLE = 5

function Toast.new(window, position)
	local place = POSITIONS[position or "BottomRight"]
	if not place then
		error("[UI] NotifyPosition must be TopRight, BottomRight, TopLeft or BottomLeft", 0)
	end
	local self = setmetatable({ _window = window, _place = place, _active = {}, _order = 0 }, Toast)
	local container = Create.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(place.x, place.y),
		Position = UDim2.new(place.x, place.x == 1 and -12 or 12, place.y, place.y == 1 and -12 or 12),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 55,
		Parent = window._overlay,
	})
	local list = Create.List(container, Enum.FillDirection.Vertical, 8)
	list.HorizontalAlignment = place.x == 1 and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
	list.VerticalAlignment = place.y == 1 and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
	self._container = container
	return self
end

function Toast:_relayout()
	local vp = self._window:_viewport()
	self._container.Size = UDim2.fromOffset(math.min(300, vp.X - 24), 0)
end

function Toast:_dismiss(entry, instant)
	if entry.dismissed then
		return
	end
	entry.dismissed = true
	for index, active in ipairs(self._active) do
		if active == entry then
			table.remove(self._active, index)
			break
		end
	end
	if instant then
		entry.wrapper:Destroy()
		return
	end
	local width = self._container.Size.X.Offset
	local dir = self._place.x == 1 and 1 or -1
	local tween = Tween.play(entry.toast, { Position = UDim2.fromOffset(dir * (width + 40), 0) }, self._window.Theme:Get().Animation.Normal)
	tween.Completed:Connect(function()
		entry.wrapper:Destroy()
	end)
end

function Toast:Push(cfg)
	Validate.check("Notify", cfg, { Title = "string", Content = "string", Duration = "number", Type = "string" })
	if cfg.Title == nil and cfg.Content == nil then
		error("[UI] Notify: needs a Title or Content", 0)
	end
	local token = TYPES[cfg.Type or "Info"]
	if not token then
		error("[UI] Notify: Type must be Info, Success, Warning or Error", 0)
	end

	local window = self._window
	local theme = window.Theme
	while #self._active >= MAX_VISIBLE do
		self:_dismiss(self._active[1], true)
	end

	self._order = self._order + 1
	local wrapper = Create.new("Frame", {
		Name = "ToastWrapper",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self._order,
		Parent = self._container,
	})
	local width = self._container.Size.X.Offset
	local dir = self._place.x == 1 and 1 or -1
	local toast = Create.new("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(dir * (width + 40), 0),
		Parent = wrapper,
	})
	theme:Bind(toast, {
		BackgroundColor3 = "Card",
		BackgroundTransparency = function(t)
			return t.Transparency.Toast
		end,
	})
	theme:Corner(toast, "Card")
	local toastStroke = theme:Stroke(toast, "Stroke", 1)
	toastStroke.Transparency = 0.4

	local bar = Create.new("Frame", {
		Name = "Accent",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(0, 3, 1, -16),
		Parent = toast,
	})
	Create.Corner(bar, UDim.new(1, 0))
	theme:Bind(bar, { BackgroundColor3 = token })

	local body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = toast,
	})
	Create.List(body, Enum.FillDirection.Vertical, 2)
	Create.Padding(body, 20, 10, 12, 10)

	if cfg.Title then
		local title = Create.new("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = cfg.Title,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 1,
			Parent = body,
		})
		theme:Text(title, "Text", "Bold", "Body")
	end
	if cfg.Content then
		local text = Create.new("TextLabel", {
			Name = "Content",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = cfg.Content,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 2,
			Parent = body,
		})
		theme:Text(text, "TextDim", "Regular", "Small")
	end

	local entry = { wrapper = wrapper, toast = toast, dismissed = false }
	self._active[#self._active + 1] = entry

	local click = Create.new("TextButton", { Name = "Dismiss", Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = toast })
	click.Activated:Connect(function()
		self:_dismiss(entry)
	end)

	Tween.play(toast, { Position = UDim2.fromOffset(0, 0) }, theme:Get().Animation.Normal)
	task.delay(cfg.Duration or 4, function()
		if wrapper.Parent then
			self:_dismiss(entry)
		end
	end)

	return {
		Dismiss = function()
			self:_dismiss(entry)
		end,
	}
end

return Toast
