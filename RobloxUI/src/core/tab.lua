local Create = require("util/create")
local Maid = require("util/maid")
local Tween = require("util/tween")
local Validate = require("util/validate")
local Icons = require("core/icons")
local Card = require("core/card")

local Tab = {}
Tab.__index = Tab

function Tab.new(window, cfg, groupItems, group)
	Validate.check("CreateTab", cfg, { Name = "string!", Icon = "string|number|boolean", Group = "string", Tint = "boolean", Heading = "string", Description = "string" })
	local theme = window.Theme
	local th = theme:Get()
	local ctx = window._ctx

	local self = setmetatable({}, Tab)
	self.Window = window
	self.Name = cfg.Name
	self._maid = window._maid:Give(Maid.new())
	self._count = 0
	self._cards = {}
	self._active, self._hover = false, false
	self._group = group

	local button = Create.new("TextButton", {
		Name = cfg.Name,
		Size = UDim2.new(1, 0, 0, ctx.TabHeight),
		BackgroundTransparency = 1,
		Parent = groupItems,
	})
	theme:Corner(button, "Control")
	local badge = Create.new("Frame", {
		Name = "IconBadge",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Parent = button,
	})
	Create.Corner(badge, UDim.new(1, 0))
	local badgeGradient = Create.new("UIGradient", { Enabled = false, Parent = badge })
	theme:Bind(badgeGradient, {
		Color = function(t)
			return ColorSequence.new(t.Colors.Accent, t.Colors.AccentAlt)
		end,
	})
	local noIcon = cfg.Icon == false or window._tabIcons == false
	local iconSpec = cfg.Icon
	if iconSpec == false then
		iconSpec = nil
	elseif iconSpec == nil and not noIcon then
		iconSpec = Icons.Guess(cfg.Name)
	end
	local icon = Icons.Make(button, iconSpec, cfg.Name, 22, { Tint = cfg.Tint })
	local label = Create.new("TextLabel", {
		Name = "Label",
		Position = UDim2.new(0, 50, 0, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Text = cfg.Name,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})
	theme:Bind(label, {
		Font = function(t)
			return t.Font.Medium
		end,
		TextSize = function(t)
			return t.TextSize.Body
		end,
	})
	self._noIcon = noIcon
	self.Button, self._icon, self._label = button, icon, label
	self._badge, self._badgeGradient = badge, badgeGradient
	self._maid:Give(button)

	local page = Create.new("ScrollingFrame", {
		Name = cfg.Name,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = ctx.Touch and 4 or 3,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Visible = false,
		Parent = window.Pages,
	})
	theme:Bind(page, { ScrollBarImageColor3 = "TextMuted" })
	self.Page = page
	self._maid:Give(page)

	local wrap = Create.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = page,
	})
	local pad = th.Spacing.Padding
	Create.Padding(wrap, pad, pad, pad, pad)
	Create.List(wrap, Enum.FillDirection.Vertical, 12)

	if cfg.Heading or cfg.Description then
		local heading = Create.new("Frame", {
			Name = "Heading",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = wrap,
		})
		Create.List(heading, Enum.FillDirection.Vertical, 4)
		if cfg.Heading then
			local title = Create.new("TextLabel", {
				Name = "Title",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = cfg.Heading,
				TextWrapped = true,
				TextColor3 = Color3.new(1, 1, 1),
				LayoutOrder = 1,
				Parent = heading,
			})
			theme:Bind(title, {
				Font = function(t)
					return t.Font.Bold
				end,
				TextSize = function(t)
					return t.TextSize.Title + 6
				end,
			})
			local titleGradient = Create.new("UIGradient", { Parent = title })
			theme:Bind(titleGradient, {
				Color = function(t)
					return ColorSequence.new(t.Colors.Text, t.Colors.Accent)
				end,
			})
		end
		if cfg.Description then
			local text = Create.new("TextLabel", {
				Name = "Description",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = cfg.Description,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				LayoutOrder = 2,
				Parent = heading,
			})
			theme:Text(text, "TextDim", "Regular", "Small")
		end
	end

	local container = Create.new("Frame", {
		Name = "Columns",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = wrap,
	})
	self._columnsLayout = Create.List(container, Enum.FillDirection.Horizontal, th.Spacing.Gap)
	self._columnsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	self._columns = {}
	for i = 1, 2 do
		local column = Create.new("Frame", {
			Name = "Column" .. i,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -th.Spacing.Gap / 2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = container,
		})
		Create.List(column, Enum.FillDirection.Vertical, th.Spacing.Gap)
		self._columns[i] = column
	end

	self._maid:Give(button.Activated:Connect(function()
		window:SelectTab(self)
	end))
	self._maid:Give(button.MouseEnter:Connect(function()
		self._hover = true
		self:_renderButton(true)
	end))
	self._maid:Give(button.MouseLeave:Connect(function()
		self._hover = false
		self:_renderButton(true)
	end))
	self._maid:Give(theme:Watch(function()
		self:_renderButton(false)
	end))

	self:_setRail(window._rail or false)
	self:_setColumns(window._twoCol and 2 or 1)
	return self
end

function Tab:_renderButton(animate)
	local th = self.Window.Theme:Get()
	local c = th.Colors
	local active, hover = self._active, self._hover
	local rowTransparency = active and 0.9 or (hover and 0.5 or 1)
	local rowColor = active and c.Accent or c.Control
	local badgeTransparency = active and 0 or 1
	self._label.TextColor3 = (active or hover) and c.Text or c.TextDim
	self._icon:Paint(active and c.AccentText or c.TextDim, active or hover)
	self._badgeGradient.Enabled = active
	if animate then
		Tween.play(self.Button, { BackgroundTransparency = rowTransparency, BackgroundColor3 = rowColor }, th.Animation.Fast)
		Tween.play(self._badge, { BackgroundTransparency = badgeTransparency }, th.Animation.Fast)
	else
		self.Button.BackgroundTransparency = rowTransparency
		self.Button.BackgroundColor3 = rowColor
		self._badge.BackgroundTransparency = badgeTransparency
	end
end

function Tab:_setActive(active)
	self._active = active
	self:_renderButton(true)
	if active then
		self.Page.Position = UDim2.new(0, 0, 0, 10)
		self.Page.Visible = true
		Tween.play(self.Page, { Position = UDim2.new(0, 0, 0, 0) }, self.Window.Theme:Get().Animation.Normal)
	else
		self.Page.Visible = false
	end
end

function Tab:_setRail(rail)
	if self._railApplied == rail then
		return
	end
	self._railApplied = rail
	self._rail = rail
	self._label.Visible = not rail
	local frame = self._icon.Frame
	local badge = self._badge
	if rail then
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.new(0.5, 0, 0.5, 0)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.5, 0, 0.5, 0)
	else
		frame.AnchorPoint = Vector2.new(0, 0.5)
		frame.Position = UDim2.new(0, 14, 0.5, 0)
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 10, 0.5, 0)
	end
	if self._noIcon then
		-- no icon: hide the icon slot in the full sidebar and start the label at the normal padding
		frame.Visible = rail
		badge.Visible = rail
		self._label.Position = UDim2.new(0, 14, 0, 0)
		self._label.Size = UDim2.new(1, -20, 1, 0)
	end
end

function Tab:_setColumns(count)
	if self._columnCount == count then
		return
	end
	self._columnCount = count
	local gap = self.Window.Theme:Get().Spacing.Gap
	if count == 2 then
		self._columnsLayout.FillDirection = Enum.FillDirection.Horizontal
		for _, column in ipairs(self._columns) do
			column.Size = UDim2.new(0.5, -gap / 2, 0, 0)
		end
	else
		self._columnsLayout.FillDirection = Enum.FillDirection.Vertical
		for _, column in ipairs(self._columns) do
			column.Size = UDim2.new(1, 0, 0, 0)
		end
	end
end

function Tab:_applyFilter(query)
	local nameMatch = query ~= "" and string.find(string.lower(self.Name), query, 1, true) ~= nil
	local total = 0
	for _, card in ipairs(self._cards) do
		total = total + card:_applyFilter(nameMatch and "" or query)
	end
	self.Button.Visible = query == "" or nameMatch or total > 0
end

function Tab:CreateCard(cfg)
	Validate.check("CreateCard", cfg, { Name = "string!", Column = "number" })
	local index = cfg.Column
	if index ~= 1 and index ~= 2 then
		index = (self._count % 2) + 1
	end
	self._count = self._count + 1
	local card = Card.new(self, cfg, self._columns[index])
	self._cards[#self._cards + 1] = card
	return card
end

function Tab:_removeCard(card)
	for index, existing in ipairs(self._cards) do
		if existing == card then
			table.remove(self._cards, index)
			break
		end
	end
end

function Tab:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for index = #self._cards, 1, -1 do
		self._cards[index]:Destroy()
	end
	self.Window:_removeTab(self)
	self._maid:Destroy()
end

function Tab:Select()
	self.Window:SelectTab(self)
end

return Tab
