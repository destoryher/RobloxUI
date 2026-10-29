local Create = require("util/create")
local Tween = require("util/tween")
local Drag = require("util/drag")
local Icons = require("core/icons")
local Glyphs = require("util/glyphs")

local Dock = {}
Dock.__index = Dock

local BAR_WIDTH = 380

local function actionButton(window, parent, order, glyph, hoverToken, onClick)
	local theme = window.Theme
	local button = Create.new("TextButton", {
		Name = "Action",
		Size = UDim2.fromOffset(34, 32),
		LayoutOrder = order,
		Parent = parent,
	})
	theme:Corner(button, "Control")
	local _, parts = glyph(button)
	local hover = false
	local function paint()
		local c = theme:Get().Colors
		button.BackgroundColor3 = c.ControlHover
		button.BackgroundTransparency = hover and 0.35 or 1
		Glyphs.paint(parts, hover and c[hoverToken] or c.TextMuted)
	end
	window._maid:Give(theme:Watch(paint))
	window._maid:Give(button.MouseEnter:Connect(function()
		hover = true
		paint()
	end))
	window._maid:Give(button.MouseLeave:Connect(function()
		hover = false
		paint()
	end))
	window._maid:Give(button.MouseButton1Down:Connect(function()
		hover = true
		paint()
	end))
	window._maid:Give(button.MouseButton1Up:Connect(function()
		hover = false
		paint()
	end))
	window._maid:Give(button.Activated:Connect(onClick))
	return button
end

-- Shared minimized look: window fill, accent gradient border.
local function styleShell(theme, frame)
	theme:Bind(frame, {
		BackgroundColor3 = "Window",
		BackgroundTransparency = function(t)
			return t.Transparency.Pill
		end,
	})
	local stroke = Create.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 2,
		Color = Color3.new(1, 1, 1),
		Parent = frame,
	})
	local gradient = Create.new("UIGradient", { Parent = stroke })
	theme:Bind(gradient, {
		Color = function(t)
			return ColorSequence.new(t.Colors.Accent, t.Colors.AccentAlt)
		end,
	})
end

local function buildPill(self, window, cfg)
	local theme = window.Theme
	self.Height = window._ctx.Touch and 48 or 44

	local frame = Create.new("Frame", {
		Name = "MinimizedPill",
		Size = UDim2.fromOffset(0, self.Height),
		AutomaticSize = Enum.AutomaticSize.X,
		Active = true,
		Visible = false,
		ZIndex = 20,
		Parent = window._root,
	})
	styleShell(theme, frame)
	Create.Corner(frame, UDim.new(1, 0))
	local list = Create.List(frame, Enum.FillDirection.Horizontal, 0)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	local handle = Create.new("Frame", {
		Name = "Handle",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 46, 1, 0),
		LayoutOrder = 1,
		Parent = frame,
	})
	local _, moveParts = Glyphs.move(handle, 18)
	local divider = Create.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(0, 1, 0.5, 0),
		LayoutOrder = 2,
		Parent = frame,
	})
	theme:Bind(divider, { BackgroundColor3 = "Divider" })

	local content = Create.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Parent = frame,
	})
	local contentList = Create.List(content, Enum.FillDirection.Horizontal, 10)
	contentList.VerticalAlignment = Enum.VerticalAlignment.Center
	Create.Padding(content, 14, 0, 20, 0)
	local icon = Icons.Make(content, cfg.FabIcon or cfg.Icon, cfg.Title, 24, { Tint = false, Corner = 6, Theme = theme })
	icon.Frame.LayoutOrder = 1
	local title = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = cfg.Title,
		LayoutOrder = 2,
		Parent = content,
	})
	theme:Text(title, "Text", "Medium", "Body")
	self.TitleLabel = title

	window._maid:Give(theme:Watch(function(t)
		Glyphs.paint(moveParts, t.Colors.TextMuted)
		if icon.Kind ~= "image" then
			icon:Paint(t.Colors.Accent)
		end
	end))

	self.Frame = frame
	self._tapAllowed = function(x)
		return x >= handle.AbsolutePosition.X + handle.AbsoluteSize.X
	end
end

local function buildBar(self, window, cfg)
	local theme = window.Theme
	self.Height = window._ctx.Touch and 46 or 42
	self.BarWidth = BAR_WIDTH

	local frame = Create.new("Frame", {
		Name = "MinimizedBar",
		Size = UDim2.fromOffset(BAR_WIDTH, self.Height),
		Active = true,
		Visible = false,
		ZIndex = 20,
		Parent = window._root,
	})
	styleShell(theme, frame)
	theme:Corner(frame, "Window")

	local icon = Icons.Make(frame, cfg.FabIcon or cfg.Icon, cfg.Title, 26, { Tint = false, Corner = 6, Theme = theme })
	icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
	icon.Frame.Position = UDim2.new(0, 12, 0.5, 0)
	window._maid:Give(theme:Watch(function(t)
		if icon.Kind ~= "image" then
			icon:Paint(t.Colors.Accent)
		end
	end))

	local text = Create.new("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.new(0, 48, 0, 0),
		Size = UDim2.new(1, -(48 + 116), 1, 0),
		Parent = frame,
	})
	local textList = Create.List(text, Enum.FillDirection.Horizontal, 8)
	textList.VerticalAlignment = Enum.VerticalAlignment.Center
	local title = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = cfg.Title,
		LayoutOrder = 1,
		Parent = text,
	})
	theme:Text(title, "Text", "Bold", "Body")
	local subtitle = Create.new("TextLabel", {
		Name = "Subtitle",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = cfg.Subtitle or "",
		Visible = cfg.Subtitle ~= nil and cfg.Subtitle ~= "",
		LayoutOrder = 2,
		Parent = text,
	})
	theme:Text(subtitle, "TextDim", "Regular", "Small")
	self.TitleLabel, self.SubtitleLabel = title, subtitle

	local actions = Create.new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(106, 32),
		Parent = frame,
	})
	local list = Create.List(actions, Enum.FillDirection.Horizontal, 2)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	actionButton(window, actions, 1, function(parent)
		return Glyphs.magnifier(parent, 16)
	end, "Text", function()
		window:Restore()
		task.defer(function()
			if window._searchBox and window._searchWrap.Visible then
				window._searchBox:CaptureFocus()
			end
		end)
	end)
	actionButton(window, actions, 2, function(parent)
		return Glyphs.square(parent, 16)
	end, "Text", function()
		window:Restore()
	end)
	actionButton(window, actions, 3, function(parent)
		return Glyphs.cross(parent, 16)
	end, "Danger", function()
		window:Destroy()
	end)

	self.Frame = frame
	self._tapAllowed = function(x)
		return x < actions.AbsolutePosition.X
	end
end

function Dock.new(window, cfg, mode)
	local self = setmetatable({ Window = window, Mode = mode }, Dock)
	if mode == "Bar" then
		buildBar(self, window, cfg)
	else
		buildPill(self, window, cfg)
	end
	self.Scale = Create.new("UIScale", { Scale = 0, Parent = self.Frame })

	local start, tapOk
	Drag.bind(self.Frame, {
		Threshold = 6,
		OnStart = function(input)
			start = self.Pos
			tapOk = self._tapAllowed(input.Position.X)
		end,
		OnDelta = function(delta)
			if start then
				self.Pos = start + delta / window._uiScale
				self:Place()
			end
		end,
		OnEnd = function(moved)
			if not moved and tapOk then
				window:Restore()
			end
		end,
	}, window._maid)

	window._maid:Give(self.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self.Frame.Visible then
			self:Place()
		end
	end))
	return self
end

function Dock:Place()
	local window = self.Window
	local vp = window:_viewport()
	local frame = self.Frame
	local size
	if self.Mode == "Bar" then
		local width = math.min(self.BarWidth, vp.X - 16)
		if frame.Size.X.Offset ~= width then
			frame.Size = UDim2.fromOffset(width, self.Height)
		end
		size = Vector2.new(width, self.Height)
	else
		size = frame.AbsoluteSize / (math.max(window._uiScale, 0.01) * math.max(self.Scale.Scale, 0.1))
		if size.X < 8 then
			size = Vector2.new(180, self.Height)
		end
	end
	local pos = self.Pos or Vector2.new(12, vp.Y * 0.35)
	pos = Vector2.new(
		math.clamp(pos.X, 0, math.max(0, vp.X - size.X)),
		math.clamp(pos.Y, 0, math.max(0, vp.Y - size.Y))
	)
	self.Pos = pos
	frame.Position = UDim2.fromOffset(math.floor(pos.X), math.floor(pos.Y))
end

function Dock:Show()
	if self.Mode == "Bar" then
		self.Pos = self.Window._pos
	end
	self.Frame.Visible = true
	self:Place()
	Tween.play(self.Scale, { Scale = 1 }, self.Window.Theme:Get().Animation.Normal, Enum.EasingStyle.Back)
end

return Dock
