local Services = require("util/services")
local Create = require("util/create")
local Maid = require("util/maid")
local Tween = require("util/tween")
local Drag = require("util/drag")
local Validate = require("util/validate")
local ThemeManager = require("theme/manager")
local Icons = require("core/icons")
local Tab = require("core/tab")
local Dock = require("core/dock")
local KeyList = require("core/keylist")
local StatTracker = require("core/stattracker")
local Keys = require("util/keys")
local Mount = require("util/mount")
local Effects = require("core/effects")
local Toast = require("core/toast")
local Dialog = require("core/dialog")

local UserInputService = Services.UserInputService

local Window = {}
Window.__index = Window

local MIN_W, MIN_H = 300, 220
local EDGE = 8
local AUTO_W, AUTO_H, AUTO_MIN = 760, 480, 0.6
local TWO_COLUMN_MIN = 420
local CLOSE = "\u{00D7}"
local MINIMIZE = "\u{2013}"
local CHEVRON = "\u{203A}"

local function topButton(window, parent, text, hoverToken)
	local theme = window.Theme
	local button = Create.new("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Text = text,
		TextSize = 20,
		Parent = parent,
	})
	theme:Corner(button, "Control")
	local hover = false
	local function render(animate)
		local th = theme:Get()
		local c = th.Colors
		button.BackgroundColor3 = c.ControlHover
		local color = hover and c[hoverToken] or c.TextDim
		if animate then
			Tween.play(button, { BackgroundTransparency = hover and 0.3 or 1, TextColor3 = color }, th.Animation.Fast)
		else
			button.BackgroundTransparency = hover and 0.3 or 1
			button.TextColor3 = color
		end
	end
	window._maid:Give(theme:Watch(function()
		render(false)
	end))
	window._maid:Give(button.MouseEnter:Connect(function()
		hover = true
		render(true)
	end))
	window._maid:Give(button.MouseLeave:Connect(function()
		hover = false
		render(true)
	end))
	window._maid:Give(button.MouseButton1Down:Connect(function()
		hover = true
		render(true)
	end))
	window._maid:Give(button.MouseButton1Up:Connect(function()
		hover = false
		render(true)
	end))
	return button
end

local function build(cfg, partial)
	Validate.check("CreateWindow", cfg, {
		Title = "string!",
		Subtitle = "string",
		Icon = "string|number",
		Theme = "string|table",
		ToggleKey = "EnumItem|string",
		Size = "Vector2",
		Footer = "string|table",
		OnClose = "function",
		Id = "string",
		TouchMode = "boolean",
		Resizable = "boolean",
		Scale = "number",
		NotifyPosition = "string",
		FabIcon = "string|number",
		MinimizeStyle = "string",
		Effects = "string",
		BrandGradient = "boolean",
		Mark = "string",
		TabIcons = "boolean",
		Glow = "number",
	})

	cfg.Icon = cfg.Icon or ("mark:" .. string.lower(cfg.Mark or "cross"))
	local self = setmetatable({}, Window)
	self._maid = Maid.new()
	partial.self = self
	self._tabs = {}
	self._trackers = {}
	self._groups = {}
	self._groupOrder = 0
	self._destroyCallbacks = {}
	self._onClose = cfg.OnClose
	self._state = "open"
	self._token = 0
	self._userRail = false
	self._userScale = cfg.Scale
	self._uiScale = 1
	self._toggleKey = Keys.parse(cfg.ToggleKey, "CreateWindow", true)
	self._size = cfg.Size or Vector2.new(640, 420)
	self._tabIcons = cfg.TabIcons ~= false

	local theme = ThemeManager.new(cfg.Theme or "Mono")
	self.Theme = theme
	local th = theme:Get()
	local sp = th.Spacing

	local touch
	if cfg.TouchMode ~= nil then
		touch = cfg.TouchMode
	else
		touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	end
	self._ctx = {
		Theme = theme,
		Touch = touch,
		RowHeight = touch and sp.RowTouch or sp.Row,
		TabHeight = touch and 44 or 38,
		Window = self,
	}

	local gui = Create.new("ScreenGui", {
		Name = "UILib",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
	})
	Mount.gui(gui)
	self._gui = gui
	self._maid:Give(gui)

	local root = Create.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local rootScale = Create.new("UIScale", { Parent = root })
	self._root, self._rootScale = root, rootScale

	local main = Create.new("Frame", { Name = "Window", Parent = root })
	theme:Bind(main, { BackgroundColor3 = "Window" })
	theme:Corner(main, "Window")
	theme:Stroke(main, "Stroke", 1)
	local scale = Create.new("UIScale", { Scale = 0.9, Parent = main })
	self._main, self._scale = main, scale
	if cfg.Effects ~= nil and cfg.Effects ~= "Full" and cfg.Effects ~= "Lite" then
		error("[UI] CreateWindow: Effects must be Full or Lite", 0)
	end
	if cfg.Effects ~= "Lite" then
		Effects.shadow(self, main, scale)
		Effects.windowGlow(self, main)
	end

	local sidebar = Create.new("Frame", { Name = "Sidebar", Size = UDim2.new(0, sp.Sidebar, 1, 0), Parent = main })
	theme:Bind(sidebar, { BackgroundColor3 = "Sidebar" })
	theme:Corner(sidebar, "Window")
	local sideFill = Create.new("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 24, 1, 0),
		Parent = sidebar,
	})
	theme:Bind(sideFill, { BackgroundColor3 = "Sidebar" })
	local sideLine = Create.new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = sidebar,
	})
	theme:Bind(sideLine, { BackgroundColor3 = "Divider" })
	self._sidebar = sidebar
	if cfg.Effects ~= "Lite" then
		Effects.sidebarGlow(self, sidebar)
	end
	Effects.accentLine(self, sidebar, Vector2.new(0, 0), UDim2.new(0, 14, 0, 63), UDim2.new(1, -28, 0, 1))

	local brand = Create.new("Frame", {
		Name = "Brand",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 64),
		Parent = sidebar,
	})
	local badgeStroke
	local brandIcon
	local function styleBrand()
		local isImage = brandIcon.Kind == "image"
		brandIcon.Frame.BackgroundTransparency = isImage and 1 or 0
		if badgeStroke then
			badgeStroke.Enabled = not isImage
		end
	end
	brandIcon = Icons.Make(brand, cfg.Icon, cfg.Title, 36, {
		Tint = false,
		Corner = 8,
		Theme = theme,
		OnChange = function()
			styleBrand()
		end,
	})
	theme:Bind(brandIcon.Frame, { BackgroundColor3 = "Control" })
	Create.Corner(brandIcon.Frame, 8)
	badgeStroke = theme:Stroke(brandIcon.Frame, "Accent", 1)
	badgeStroke.Transparency = 0.55
	self._maid:Give(theme:Watch(function(t)
		if brandIcon.Kind ~= "image" then
			brandIcon:Paint(t.Colors.Accent)
		end
	end))
	styleBrand()
	self._brandIcon = brandIcon

	local brandText = Create.new("Frame", {
		Name = "BrandText",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 58, 0, 0),
		Size = UDim2.new(1, -66, 1, 0),
		Parent = brand,
	})
	local titleLabel = Create.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 0, 0, 14),
		Size = UDim2.new(1, 0, 0, 20),
		Text = cfg.Title,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = brandText,
	})
	if cfg.BrandGradient == false then
		theme:Text(titleLabel, "Text", "Bold", "Header")
	else

		titleLabel.TextColor3 = Color3.new(1, 1, 1)
		theme:Bind(titleLabel, {
			Font = function(t)
				return t.Font.Bold
			end,
			TextSize = function(t)
				return t.TextSize.Header + 3
			end,
		})
		local titleGradient = Create.new("UIGradient", { Parent = titleLabel })
		theme:Bind(titleGradient, {
			Color = function(t)
				return ColorSequence.new(t.Colors.Text, t.Colors.Accent)
			end,
		})
	end
	local subtitleLabel = Create.new("TextLabel", {
		Name = "Subtitle",
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, 16),
		Text = cfg.Subtitle or "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = brandText,
	})
	theme:Text(subtitleLabel, "TextMuted", "Regular", "Small")

	self._brandText, self._brandTitle, self._brandSubtitle = brandText, titleLabel, subtitleLabel

	local footerCfg = cfg.Footer
	if type(footerCfg) == "string" then
		footerCfg = { Text = footerCfg }
	end
	if footerCfg then
		Validate.check("CreateWindow Footer", footerCfg, { Text = "string", Subtext = "string", Avatar = "boolean" })
	end
	local showKey = cfg.ToggleKey ~= nil and not touch
	local footerH = 0
	if footerCfg or showKey then
		footerH = (footerCfg and footerCfg.Avatar) and 58 or 38
		local footer = Create.new("Frame", {
			Name = "Footer",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, footerH),
			Parent = sidebar,
		})
		local footerLine = Create.new("Frame", { Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 0), Parent = footer })
		theme:Bind(footerLine, { BackgroundColor3 = "Divider" })

		local textX = 14
		local player = Services.Players and Services.Players.LocalPlayer
		if footerCfg and footerCfg.Avatar then
			local avatar = Create.new("ImageLabel", {
				Name = "Avatar",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 1),
				Size = UDim2.fromOffset(34, 34),
				BackgroundTransparency = 0,
				Parent = footer,
			})
			Create.Corner(avatar, UDim.new(1, 0))
			theme:Bind(avatar, { BackgroundColor3 = "Control" })
			textX = 54
			if player then
				task.spawn(function()
					local ok, image = pcall(function()
						return Services.Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
					end)
					if ok and avatar.Parent then
						avatar.Image = image
					end
				end)
			end
		end

		local reserve = textX + (showKey and 76 or 12)
		if footerCfg then
			local text = footerCfg.Text
			if text == nil and footerCfg.Avatar and player then
				text = player.DisplayName
			end
			local hasSub = footerCfg.Subtext ~= nil
			local plain = not footerCfg.Avatar and not hasSub
			if text then
				local label = Create.new("TextLabel", {
					Name = "Text",
					Position = hasSub and UDim2.new(0, textX, 0.5, -16) or UDim2.new(0, textX, 0, 1),
					Size = hasSub and UDim2.new(1, -reserve, 0, 16) or UDim2.new(1, -reserve, 1, -1),
					Text = text,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = footer,
				})
				theme:Text(label, plain and "TextMuted" or "Text", plain and "Regular" or "Medium", plain and "Small" or "Body")
			end
			if hasSub then
				local sub = Create.new("TextLabel", {
					Name = "Subtext",
					Position = UDim2.new(0, textX, 0.5, 1),
					Size = UDim2.new(1, -reserve, 0, 14),
					Text = footerCfg.Subtext,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = footer,
				})
				theme:Text(sub, "TextMuted", "Regular", "Small")
			end
		end

		if showKey then
			local badge = Create.new("Frame", {
				Name = "KeyHint",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 1),
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				Parent = footer,
			})
			theme:Bind(badge, { BackgroundColor3 = "Control" })
			theme:Corner(badge, 6)
			theme:Stroke(badge, "Stroke", 1)
			local keyLabel = Create.new("TextLabel", {
				Size = UDim2.fromOffset(0, 22),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = Keys.text(self._toggleKey),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = badge,
			})
			Create.Padding(keyLabel, 8, 0, 8, 0)
			theme:Text(keyLabel, "TextDim", "Medium", "Small")
			self._keyBadge = keyLabel
		end
		self._footer = footer
	end

	local tabList = Create.new("ScrollingFrame", {
		Name = "Tabs",
		Position = UDim2.new(0, 0, 0, 64),
		Size = UDim2.new(1, 0, 1, -(64 + footerH)),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = sidebar,
	})
	theme:Bind(tabList, { ScrollBarImageColor3 = "TextMuted" })
	Create.Padding(tabList, 8, 4, 8, 8)
	Create.List(tabList, Enum.FillDirection.Vertical, 6)
	self._tabList = tabList

	local content = Create.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, sp.Sidebar, 0, 0),
		Size = UDim2.new(1, -sp.Sidebar, 1, 0),
		Parent = main,
	})
	self._content = content

	local topbar = Create.new("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, sp.TopBar),
		Parent = content,
	})
	local topLine = Create.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = topbar,
	})
	theme:Bind(topLine, { BackgroundColor3 = "Divider" })
	Effects.accentLine(self, topbar, Vector2.new(0, 1), UDim2.new(0, 0, 1, 0), UDim2.new(0.6, 0, 0, 1))

	local hamburger = Create.new("TextButton", {
		Name = "SidebarToggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Parent = topbar,
	})
	theme:Corner(hamburger, "Control")
	local bars = {}
	for i = 1, 3 do
		local bar = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (i - 2) * 5),
			Size = UDim2.fromOffset(14, 2),
			Parent = hamburger,
		})
		Create.Corner(bar, UDim.new(1, 0))
		bars[i] = bar
	end
	self._maid:Give(theme:Watch(function(t)
		hamburger.BackgroundColor3 = t.Colors.ControlHover
		hamburger.BackgroundTransparency = 1
		for _, bar in ipairs(bars) do
			bar.BackgroundColor3 = t.Colors.TextDim
		end
	end))
	self._hamburger = hamburger

	local pageTitle = Create.new("TextLabel", {
		Name = "PageTitle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.new(1, -250, 1, 0),
		Text = "",
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = topbar,
	})
	pageTitle.AnchorPoint = Vector2.new(0, 0.5)
	pageTitle.Position = UDim2.new(0, 48, 0.5, 0)
	theme:Text(pageTitle, "Text", "Bold", "Title")
	self._pageTitle = pageTitle
	self._maid:Give(theme:Watch(function()
		self:_updateTitle()
	end))

	local actions = Create.new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 0, 0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = topbar,
	})
	local actionsList = Create.List(actions, Enum.FillDirection.Horizontal, 6)
	actionsList.VerticalAlignment = Enum.VerticalAlignment.Center

	local searchWrap = Create.new("Frame", {
		Name = "Search",
		Size = UDim2.fromOffset(176, 30),
		LayoutOrder = 1,
		Parent = actions,
	})
	theme:Bind(searchWrap, { BackgroundColor3 = "Control" })
	theme:Corner(searchWrap, "Control")

	local magnifier = Create.new("Frame", {
		Name = "Magnifier",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		Parent = searchWrap,
	})
	local ring = Create.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(9, 9), Parent = magnifier })
	Create.Corner(ring, UDim.new(1, 0))
	theme:Stroke(ring, "TextMuted", 1.5)
	local handle = Create.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(11, 11),
		Size = UDim2.fromOffset(5, 2),
		Rotation = 45,
		Parent = magnifier,
	})
	theme:Bind(handle, { BackgroundColor3 = "TextMuted" })
	local searchBox = Create.new("TextBox", {
		Name = "Input",
		Position = UDim2.new(0, 30, 0, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Text = "",
		PlaceholderText = "Search...",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = searchWrap,
	})
	theme:Text(searchBox, "Text", "Regular", "Body")
	theme:Bind(searchBox, { PlaceholderColor3 = "TextMuted" })
	self._searchWrap, self._searchBox = searchWrap, searchBox

	local minimizeButton = topButton(self, actions, MINIMIZE, "Text")
	minimizeButton.Name = "Minimize"
	minimizeButton.LayoutOrder = 2
	local closeButton = topButton(self, actions, CLOSE, "Danger")
	closeButton.Name = "Close"
	closeButton.LayoutOrder = 3

	local pages = Create.new("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.new(0, 0, 0, sp.TopBar),
		Size = UDim2.new(1, 0, 1, -sp.TopBar),
		Parent = content,
	})
	self.Pages = pages

	local gripSize = touch and 30 or 22
	local grip = Create.new("TextButton", {
		Name = "ResizeGrip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		Size = UDim2.fromOffset(gripSize, gripSize),
		ZIndex = 10,
		Visible = cfg.Resizable ~= false,
		Parent = main,
	})
	for i = 1, 2 do
		local line = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, i == 1 and -8 or -6, 1, i == 1 and -8 or -6),
			Size = UDim2.fromOffset(i == 1 and 12 or 6, 1),
			Rotation = -45,
			ZIndex = 10,
			Parent = grip,
		})
		theme:Bind(line, { BackgroundColor3 = "TextMuted" })
	end

	self._cfg, self._touch = cfg, touch
	self:_buildDock(self:_resolveDockMode(cfg.MinimizeStyle or "Auto"))

	self._overlay = Create.new("Frame", {
		Name = "Overlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = root,
	})
	self._toasts = Toast.new(self, cfg.NotifyPosition)

	local dragStart
	local function startDrag()
		dragStart = self._pos
	end
	local function moveDrag(delta)
		if dragStart then
			self._pos = dragStart + delta / self._uiScale
			self:_place()
		end
	end
	Drag.bind(topbar, { OnStart = startDrag, OnDelta = moveDrag }, self._maid)
	Drag.bind(brand, { OnStart = startDrag, OnDelta = moveDrag }, self._maid)

	local resizeStart
	Drag.bind(grip, {
		OnStart = function()
			resizeStart = Vector2.new(self._curW, self._curH)
			self._resizing = true
		end,
		OnDelta = function(delta)
			if resizeStart then
				self._size = resizeStart + delta / self._uiScale
				self:_queueLayout()
			end
		end,
		OnEnd = function()
			self._resizing = false
			self._size = Vector2.new(self._curW, self._curH)
		end,
	}, self._maid)

	self._maid:Give(minimizeButton.Activated:Connect(function()
		self:Minimize()
	end))
	self._maid:Give(closeButton.Activated:Connect(function()
		self:Destroy()
	end))
	self._maid:Give(hamburger.Activated:Connect(function()
		self:SetSidebarCollapsed(not self._userRail)
	end))
	-- filter after a short pause in typing, not on every keystroke
	local searchToken = 0
	self._maid:Give(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchToken = searchToken + 1
		local token = searchToken
		local text = searchBox.Text
		if text == "" then
			self:_filter("")
			return
		end
		task.delay(0.12, function()
			if token == searchToken and not self._destroyed then
				self:_filter(text)
			end
		end)
	end))
	self._maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_closePopup()
		self:_queueLayout()
	end))
	self._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not self._toggleKey or Keys.blocked(input) then
			return
		end
		if Keys.matches(input, self._toggleKey) then
			self:Toggle()
		end
	end))

	self:_layout(false)
	self:_placeFab()
	Tween.play(scale, { Scale = 1 }, th.Animation.Normal)
	if cfg.Glow ~= nil then
		self:SetGlow(cfg.Glow)
	end
	return self
end

function Window.new(cfg)
	local partial = {}
	local ok, result = pcall(build, cfg, partial)
	if not ok then
		if partial.self then
			pcall(function()
				partial.self._maid:Destroy()
			end)
		end
		error(result, 0)
	end
	return result
end

function Window:_queueLayout()
	if self._layoutQueued or self._destroyed then
		return
	end
	self._layoutQueued = true
	task.defer(function()
		self._layoutQueued = false
		if self._destroyed then
			return
		end
		self:_layout(false)
		self:_placeFab()
		if self._resizing then
			self._size = Vector2.new(self._curW, self._curH)
		end
	end)
end

function Window:_updateScale()
	local abs = self._gui.AbsoluteSize
	local scale = self._userScale
	if not scale then
		scale = math.clamp(math.min(abs.Y / AUTO_H, abs.X / AUTO_W), AUTO_MIN, 1)
	end
	scale = math.clamp(scale, 0.5, 2)
	self._uiScale = scale
	self._rootScale.Scale = scale
	self._root.Size = UDim2.fromOffset(abs.X / scale, abs.Y / scale)
end

-- Factor between unscaled layout pixels and absolute pixels, or nil while the open/close animation runs
-- (text is re-fitted once the animation settles, instead of every frame).
function Window:_textScale()
	local anim = self._scale.Scale
	if anim < 0.999 then
		return nil
	end
	return math.max(self._uiScale * anim, 0.01)
end

function Window:_viewport()
	return self._gui.AbsoluteSize / self._uiScale
end

function Window:SetScale(scale)
	self._userScale = scale
	self:_layout(false)
	self:_placeFab()
end

function Window:_place()
	local vp = self:_viewport()
	local pos = self._pos
	if not pos then
		return
	end
	local w = self._curW
	local x = math.clamp(pos.X, 100 - w, math.max(vp.X - 100, 100 - w))
	local y = math.clamp(pos.Y, 0, math.max(0, vp.Y - 48))
	self._pos = Vector2.new(x, y)
	self._main.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end

function Window:_layout(animate)
	if self._destroyed then
		return
	end
	local theme = self.Theme:Get()
	local sp = theme.Spacing
	self:_updateScale()
	local vp = self:_viewport()
	if vp.X <= 0 or vp.Y <= 0 then
		return
	end

	local w = math.floor(math.max(MIN_W, math.min(self._size.X, vp.X - EDGE * 2)))
	local h = math.floor(math.max(MIN_H, math.min(self._size.Y, vp.Y - EDGE * 2)))
	self._curW, self._curH = w, h

	local compactBelow = sp.Sidebar + TWO_COLUMN_MIN + 4
	local compact = w < compactBelow
	local rail = compact or self._userRail
	local sidebarW = rail and sp.SidebarRail or sp.Sidebar
	local twoColumns = (w - sidebarW) >= TWO_COLUMN_MIN
	self._compact, self._rail, self._twoCol = compact, rail, twoColumns

	self._main.Size = UDim2.fromOffset(w, h)
	if not self._pos then
		self._pos = Vector2.new((vp.X - w) / 2, (vp.Y - h) / 2)
	end
	self:_place()

	local function apply(inst, props)
		if animate then
			Tween.play(inst, props, theme.Animation.Normal)
		else
			for key, value in pairs(props) do
				inst[key] = value
			end
		end
	end
	apply(self._sidebar, { Size = UDim2.new(0, sidebarW, 1, 0) })
	apply(self._content, {
		Position = UDim2.new(0, sidebarW, 0, 0),
		Size = UDim2.new(1, -sidebarW, 1, 0),
	})

	self._brandText.Visible = not rail
	if rail then
		self._brandIcon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
		self._brandIcon.Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	else
		self._brandIcon.Frame.AnchorPoint = Vector2.new(0, 0.5)
		self._brandIcon.Frame.Position = UDim2.new(0, 14, 0.5, 0)
	end
	if self._footer then
		self._footer.Visible = not rail
	end
	for _, group in pairs(self._groups) do
		if group.Header then
			group.Header.Visible = not rail
		end
	end

	local leftInset = compact and 14 or 48
	self._hamburger.Visible = not compact
	local searchW = 0
	if w >= 400 then
		searchW = w < compactBelow and 120 or 176
	end
	self._searchWrap.Visible = searchW > 0
	self._searchWrap.Size = UDim2.fromOffset(searchW, 30)
	local actionsW = (searchW > 0 and (searchW + 6) or 0) + 66
	self._pageTitle.Position = UDim2.new(0, leftInset, 0.5, 0)
	self._pageTitle.Size = UDim2.new(1, -(leftInset + actionsW + 18), 1, 0)

	for _, tab in ipairs(self._tabs) do
		tab:_setRail(rail)
		tab:_setColumns(twoColumns and 2 or 1)
	end
	if self._toasts then
		self._toasts:_relayout()
	end
end

function Window:_resolveDockMode(style)
	if style ~= "Auto" and style ~= "Pill" and style ~= "Bar" then
		error("[UI] MinimizeStyle must be Auto, Pill or Bar", 0)
	end
	if style == "Auto" then
		return self._touch and "Pill" or "Bar"
	end
	return style
end

function Window:_buildDock(mode)
	local previous = self._dock
	if previous then
		previous.Frame:Destroy()
	end
	self._dock = Dock.new(self, self._cfg, mode)
	if previous then
		self._dock.Pos = previous.Pos
	end
	self._fab, self._fabScale = self._dock.Frame, self._dock.Scale
end

function Window:SetMinimizeStyle(style)
	local mode = self:_resolveDockMode(style)
	if mode == self._dock.Mode then
		return
	end
	self:_buildDock(mode)
	if self._state == "minimized" then
		self._dock:Show()
	end
end

function Window:_placeFab()
	if self._dock and self._dock.Frame.Visible then
		self._dock:Place()
	end
	if self._keylist and self._keylist.Frame.Visible then
		self._keylist:_place()
	end
	for _, tracker in ipairs(self._trackers) do
		if tracker.Frame.Visible then
			tracker:_place()
		end
	end
end

function Window:_transition(state)
	self:_closePopup()
	self._state = state
	if self._keylist then
		self._keylist:_sync()
	end
	for _, tracker in ipairs(self._trackers) do
		tracker:_sync()
	end
	self._token = self._token + 1
	local token = self._token
	local anim = self.Theme:Get().Animation

	if state == "open" then
		if self._dock.Mode == "Bar" and self._fab.Visible then
			self._pos = self._dock.Pos
			self:_place()
		end
		self._main.Visible = true
		Tween.play(self._scale, { Scale = 1 }, anim.Normal)
		if self._fab.Visible then
			local tween = Tween.play(self._fabScale, { Scale = 0 }, anim.Fast)
			tween.Completed:Connect(function()
				if self._token == token then
					self._fab.Visible = false
				end
			end)
		end
	else
		local tween = Tween.play(self._scale, { Scale = 0.9 }, anim.Fast)
		tween.Completed:Connect(function()
			if self._token == token then
				self._main.Visible = false
			end
		end)
		if state == "minimized" then
			self._dock:Show()
		elseif self._fab.Visible then
			self._fabScale.Scale = 0
			self._fab.Visible = false
		end
	end
end

function Window:Minimize()
	if self._destroyed or self._state == "minimized" then
		return
	end
	self:_transition("minimized")
end

function Window:Restore()
	if self._destroyed or self._state == "open" then
		return
	end
	self:_transition("open")
end

function Window:Hide()
	if self._destroyed or self._state == "hidden" then
		return
	end
	self:_transition("hidden")
end

function Window:Toggle()
	if self._state == "open" then
		self:Hide()
	else
		self:Restore()
	end
end

function Window:IsOpen()
	return self._state == "open"
end

function Window:IsVisible()
	return self._state == "open"
end

function Window:Show()
	self:Restore()
end

function Window:SetToggleKey(keyCode)
	keyCode = Keys.parse(keyCode, "SetToggleKey", true)
	self._toggleKey = keyCode
	if self._keyBadge then
		self._keyBadge.Text = Keys.text(keyCode)
	end
end

function Window:SetSidebarCollapsed(collapsed)
	self._userRail = collapsed and true or false
	self:_layout(true)
end

function Window:_group(name)
	name = name or ""
	local existing = self._groups[name]
	if existing then
		return existing
	end
	self._groupOrder = self._groupOrder + 1
	local theme = self.Theme
	local group = { Name = name, Tabs = {} }

	local frame = Create.new("Frame", {
		Name = "Group_" .. name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = name == "" and 0 or self._groupOrder,
		Parent = self._tabList,
	})
	Create.List(frame, Enum.FillDirection.Vertical, 2)
	group.Frame = frame

	if name ~= "" then
		local header = Create.new("TextButton", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 1,
			Parent = frame,
		})
		local text = Create.new("TextLabel", {
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(1, -36, 1, 0),
			Text = name,
			Parent = header,
		})
		theme:Text(text, "TextDim", "Medium", "Small")
		local chevron = Create.new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			Text = CHEVRON,
			TextXAlignment = Enum.TextXAlignment.Center,
			Rotation = 90,
			Parent = header,
		})
		theme:Text(chevron, "TextMuted", "Bold", "Header")
		group.Header = header
		group.Chevron = chevron
		self._maid:Give(header.Activated:Connect(function()
			group.Items.Visible = not group.Items.Visible
			Tween.play(chevron, { Rotation = group.Items.Visible and 90 or 0 }, theme:Get().Animation.Fast)
		end))
	end

	local items = Create.new("Frame", {
		Name = "Items",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = frame,
	})
	Create.List(items, Enum.FillDirection.Vertical, 2)
	group.Items = items

	self._groups[name] = group
	return group
end

function Window:CreateTab(cfg)
	if self._destroyed then
		error("[UI] CreateTab: this window was destroyed", 0)
	end
	Validate.check("CreateTab", cfg, { Name = "string!", Icon = "string|number|boolean", Group = "string" })
	for _, existing in ipairs(self._tabs) do
		if existing.Name == cfg.Name then
			error(("[UI] CreateTab: a tab named '%s' already exists"):format(cfg.Name), 0)
		end
	end
	local group = self:_group(cfg.Group)
	local tab = Tab.new(self, cfg, group.Items, group)
	group.Tabs[#group.Tabs + 1] = tab
	self._tabs[#self._tabs + 1] = tab
	if not self._current then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	if self._destroyed or self._current == tab then
		return
	end
	self:_closePopup()
	if self._current then
		self._current:_setActive(false)
	end
	self._current = tab
	tab:_setActive(true)
	self:_updateTitle()
end

local function escapeRich(text)
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	return text
end

function Window:_updateTitle()
	local tab = self._current
	if not tab then
		self._pageTitle.Text = ""
		return
	end
	local group = tab._group and tab._group.Name or ""
	if group == "" then
		self._pageTitle.Text = escapeRich(tab.Name)
	else
		local muted = self.Theme:Get().Colors.TextMuted:ToHex()
		self._pageTitle.Text = ('<font color="#%s">%s  \u{203A}  </font>%s'):format(muted, escapeRich(group), escapeRich(tab.Name))
	end
end

function Window:_removeTab(tab)
	for index, existing in ipairs(self._tabs) do
		if existing == tab then
			table.remove(self._tabs, index)
			break
		end
	end
	local group = tab._group
	if group then
		for index, existing in ipairs(group.Tabs) do
			if existing == tab then
				table.remove(group.Tabs, index)
				break
			end
		end
	end
	if self._current == tab then
		self._current = nil
		if self._tabs[1] then
			self:SelectTab(self._tabs[1])
		else
			self:_updateTitle()
		end
	end
end

function Window:_filter(text)
	local query = string.lower(string.match(text or "", "^%s*(.-)%s*$"))
	for _, tab in ipairs(self._tabs) do
		tab:_applyFilter(query)
	end
	for _, group in pairs(self._groups) do
		local any = false
		for _, tab in ipairs(group.Tabs) do
			if tab.Button.Visible then
				any = true
				break
			end
		end
		group.Frame.Visible = any
	end
end

function Window:_closePopup()
	if self._popup then
		self._popup.Close()
	end
end

function Window:Notify(cfg)
	if self._destroyed then
		return nil
	end
	return self._toasts:Push(cfg)
end

function Window:CreateKeybindList(cfg)
	if self._destroyed then
		return nil
	end
	if self._keylist then
		self._keylist:Destroy()
	end
	self._keylist = KeyList.new(self, cfg or {})
	self._keylist:_sync()
	return self._keylist
end

function Window:GetKeybindList()
	return self._keylist
end

-- A Stats tab plus a floating overlay that shows while the window is minimized. See core/stattracker.lua.
function Window:CreateStatTracker(cfg)
	if self._destroyed then
		return nil
	end
	local tracker = StatTracker.new(self, cfg or {})
	self._trackers[#self._trackers + 1] = tracker
	tracker:_sync()
	return tracker
end

function Window:GetStatTracker(index)
	return self._trackers[index or 1]
end

function Window:_removeTracker(tracker)
	for i, item in ipairs(self._trackers) do
		if item == tracker then
			table.remove(self._trackers, i)
			break
		end
	end
end

function Window:Confirm(cfg)
	if self._destroyed then
		return nil
	end
	return Dialog.open(self, cfg)
end

function Window:SetTitle(text)
	self._brandTitle.Text = tostring(text)
end

function Window:SetSubtitle(text)
	self._brandSubtitle.Text = tostring(text)
end

function Window:SetColor(token, color)
	if typeof(color) ~= "Color3" then
		error("[UI] SetColor expects a Color3", 0)
	end
	if self.Theme:Get().Colors[token] == nil then
		error(("[UI] SetColor: unknown color token '%s'"):format(tostring(token)), 0)
	end
	self.Theme:Patch({ Colors = { [token] = color } })
end

function Window:SetAccent(color)
	self:SetColor("Accent", color)
end

function Window:SetGradient(first, second)
	if typeof(first) ~= "Color3" or typeof(second) ~= "Color3" then
		error("[UI] SetGradient expects two Color3 values", 0)
	end
	self.Theme:Patch({ Colors = { Accent = first, AccentAlt = second } })
end

function Window:SetGlow(strength)
	if type(strength) ~= "number" then
		error("[UI] SetGlow expects a number", 0)
	end
	strength = math.clamp(strength, 0, 3)
	local base = self.Theme._base
	self.Theme:Patch({
		Transparency = {
			Glow = math.clamp(1 - (1 - base.Glow) * strength, 0, 1),
			BrandGlow = math.clamp(1 - (1 - base.BrandGlow) * strength, 0, 1),
		},
	})
end

function Window:SetTheme(spec)
	self.Theme:Set(spec)
end

function Window:_onDestroy(fn)
	self._destroyCallbacks[#self._destroyCallbacks + 1] = fn
end

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._onClose then
		local ok, err = pcall(self._onClose)
		if not ok then
			warn("[UI] OnClose errored: " .. tostring(err))
		end
	end
	for _, fn in ipairs(self._destroyCallbacks) do
		pcall(fn)
	end
	self._maid:Destroy()
end

return Window
