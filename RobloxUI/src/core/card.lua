local Create = require("util/create")
local Maid = require("util/maid")
local Tween = require("util/tween")
local Validate = require("util/validate")
local Fit = require("util/fit")
local Icons = require("core/icons")
local Toggle = require("components/toggle")
local Button = require("components/button")
local Label = require("components/label")
local Dropdown = require("components/dropdown")
local Slider = require("components/slider")
local Input = require("components/input")
local Keybind = require("components/keybind")
local ColorPicker = require("components/colorpicker")
local Paragraph = require("components/paragraph")
local Divider = require("components/divider")
local Progress = require("components/progress")
local Stat = require("components/stat")
local Chips = require("components/chips")

local Card = {}
Card.__index = Card

function Card.new(tab, cfg, column)
	Validate.check("CreateCard", cfg, {
		Name = "string!",
		Icon = "string|number",
		Collapsed = "boolean",
		Column = "number",
		Highlight = "boolean",
	})
	local window = tab.Window
	local theme = window.Theme
	local th = theme:Get()
	local sp = th.Spacing

	local self = setmetatable({}, Card)
	self._ctx = window._ctx
	self._tab = tab
	self._name = cfg.Name
	self._controls = {}
	self._orderCounter = 0
	self._collapsed = cfg.Collapsed == true
	self._animating = false
	self._token = 0
	self._maid = tab._maid:Give(Maid.new())

	local frame = Create.new("Frame", {
		Name = "Card",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = column,
	})
	local highlight = cfg.Highlight == true
	theme:Bind(frame, {
		BackgroundColor3 = function(t)
			return highlight and Color3.new(1, 1, 1) or t.Colors.Card
		end,
		BackgroundTransparency = function(t)
			return t.Transparency.Card
		end,
	})
	local sheen = Create.new("UIGradient", { Rotation = highlight and 25 or 90, Parent = frame })
	theme:Bind(sheen, {
		Color = function(t)
			if highlight then
				return ColorSequence.new(t.Colors.Card:Lerp(t.Colors.Accent, 0.16), t.Colors.Card:Lerp(t.Colors.AccentAlt, 0.08))
			end
			return ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.88, 0.88, 0.88))
		end,
	})
	theme:Corner(frame, "Card")
	local cardStroke = theme:Stroke(frame, highlight and "Accent" or "Stroke", 1)
	if highlight then
		cardStroke.Transparency = 0.45
	end
	Create.List(frame, Enum.FillDirection.Vertical, 0)
	self.Frame = frame
	self._maid:Give(frame)

	local header = Create.new("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, sp.Header),
		LayoutOrder = 1,
		Parent = frame,
	})
	local titleX = 14
	if cfg.Icon ~= nil then
		local badge = Create.new("Frame", {
			Name = "IconBadge",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(28, 28),
			Parent = header,
		})
		theme:Bind(badge, { BackgroundColor3 = "Control" })
		Create.Corner(badge, 7)
		local icon = Icons.Make(badge, cfg.Icon, cfg.Name, 18)
		icon.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Frame.Position = UDim2.fromScale(0.5, 0.5)
		self._maid:Give(theme:Watch(function(t)
			icon:Paint(t.Colors.Accent, true)
		end))
		titleX = 48
	end
	local title = Create.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, titleX, 0, 0),
		Size = UDim2.new(1, -(titleX + 40), 1, 0),
		Text = cfg.Name,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	theme:Text(title, "Text", "Bold", "Header")
	self._title = title
	Fit.bind({
		label = title,
		container = header,
		base = sp.Header,
		reserve = titleX + 40,
		maid = self._maid,
		scale = function()
			return window:_textScale()
		end,
	})

	local chevron = Create.new("TextLabel", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Text = "\u{203A}",
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = self._collapsed and 0 or 90,
		Parent = header,
	})
	theme:Text(chevron, "TextDim", "Bold", "Title")
	self._chevron = chevron

	local dividerWrap = Create.new("Frame", {
		Name = "Divider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 2,
		Parent = frame,
	})
	Create.Padding(dividerWrap, 10, 0, 10, 0)
	local divider = Create.new("Frame", { Size = UDim2.fromScale(1, 1), Parent = dividerWrap })
	theme:Bind(divider, { BackgroundColor3 = "Divider" })

	local clip = Create.new("Frame", {
		Name = "Clip",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = self._collapsed and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = frame,
	})
	local body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = clip,
	})
	local list = Create.List(body, Enum.FillDirection.Vertical, 6)
	Create.Padding(body, 10, 8, 10, 10)
	self.Body, self._clip, self._list = body, clip, list

	self._maid:Give(header.Activated:Connect(function()
		self:SetCollapsed(not self._collapsed)
	end))
	return self
end

function Card:_nextOrder()
	self._orderCounter = self._orderCounter + 1
	return self._orderCounter
end

function Card:_register(control)
	self._controls[control] = true
end

function Card:_unregister(control)
	self._controls[control] = nil
end

function Card:SetCollapsed(collapsed)
	collapsed = collapsed and true or false
	if collapsed == self._collapsed then
		return
	end
	self._collapsed = collapsed
	self._token = self._token + 1
	local token = self._token
	local th = self._ctx.Theme:Get()
	local clip = self._clip

	local window = self._ctx.Window
	local scale = window._uiScale * window._scale.Scale
	local height = self.Body.AbsoluteSize.Y / math.max(scale, 0.01)

	Tween.play(self._chevron, { Rotation = collapsed and 0 or 90 }, th.Animation.Normal)
	if collapsed then
		clip.AutomaticSize = Enum.AutomaticSize.None
		clip.Size = UDim2.new(1, 0, 0, height)
		Tween.play(clip, { Size = UDim2.new(1, 0, 0, 0) }, th.Animation.Normal)
	else
		clip.AutomaticSize = Enum.AutomaticSize.None
		local tween = Tween.play(clip, { Size = UDim2.new(1, 0, 0, height) }, th.Animation.Normal)
		tween.Completed:Connect(function()
			if self._token == token and not self._collapsed then
				clip.AutomaticSize = Enum.AutomaticSize.Y
				clip.Size = UDim2.new(1, 0, 0, 0)
			end
		end)
	end
end

function Card:IsCollapsed()
	return self._collapsed
end

function Card:SetName(text)
	self._name = tostring(text)
	self._title.Text = self._name
end

function Card:_applyFilter(query)
	if query == "" then
		for control in pairs(self._controls) do
			control:_setFiltered(false)
		end
		self.Frame.Visible = true
		return 1
	end
	local titleMatch = string.find(string.lower(self._name), query, 1, true) ~= nil
	local count = 0
	for control in pairs(self._controls) do
		local match = titleMatch or control:_matches(query)
		control:_setFiltered(not match)
		if match then
			count = count + 1
		end
	end
	local visible = titleMatch or count > 0
	self.Frame.Visible = visible
	return visible and math.max(count, 1) or 0
end

function Card:CreateToggle(cfg)
	return Toggle.new(self, cfg)
end

function Card:CreateButton(cfg)
	return Button.new(self, cfg)
end

function Card:CreateLabel(cfg)
	return Label.new(self, cfg)
end

function Card:CreateDropdown(cfg)
	return Dropdown.new(self, cfg)
end

function Card:CreateSlider(cfg)
	return Slider.new(self, cfg)
end

function Card:CreateInput(cfg)
	return Input.new(self, cfg)
end

function Card:CreateKeybind(cfg)
	return Keybind.new(self, cfg)
end

function Card:CreateColorPicker(cfg)
	return ColorPicker.new(self, cfg)
end

function Card:CreateParagraph(cfg)
	return Paragraph.new(self, cfg)
end

function Card:CreateProgress(cfg)
	return Progress.new(self, cfg)
end

function Card:CreateStat(cfg)
	return Stat.new(self, cfg)
end

function Card:CreateChips(cfg)
	return Chips.new(self, cfg)
end

function Card:CreateDivider(cfg)
	return Divider.new(self, cfg)
end

function Card:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for control in pairs(self._controls) do
		control:Destroy()
	end
	self._tab:_removeCard(self)
	self._maid:Destroy()
end

return Card
