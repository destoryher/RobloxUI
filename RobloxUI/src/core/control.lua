local Create = require("util/create")
local Maid = require("util/maid")
local Fit = require("util/fit")

local Control = {}
Control.__index = Control

function Control.base(card, cfg, kind, class)
	local ctx = card._ctx
	local self = setmetatable({}, class or Control)
	self._ctx = ctx
	self._card = card
	self._kind = kind
	self._name = cfg.Name or cfg.Text or ""
	self._cb = cfg.Callback
	self._disabled = false
	self._visible = true
	self._filtered = false
	self._renderers = {}
	self._maid = Maid.new()

	self.Row = Create.new("Frame", {
		Name = kind,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = card:_nextOrder(),
	})
	Create.List(self.Row, Enum.FillDirection.Vertical, 2)
	self.Header = Create.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ctx.RowHeight),
		LayoutOrder = 1,
		Parent = self.Row,
	})
	self.Row.Parent = card.Body

	self._maid:Give(ctx.Theme:Watch(function()
		self:_rerender(false)
	end))
	card:_register(self)
	return self
end

function Control:_onRender(fn)
	self._renderers[#self._renderers + 1] = fn
	fn(self._ctx.Theme:Get(), false)
end

function Control:_rerender(animate)
	local theme = self._ctx.Theme:Get()
	for _, fn in ipairs(self._renderers) do
		local ok, err = pcall(fn, theme, animate)
		if not ok and not self._warned then
			self._warned = true
			warn(("[UI] render error in %s '%s': %s"):format(self._kind, self._name, tostring(err)))
		end
	end
end

-- Long text wraps onto extra lines and the header grows, instead of being cut off with "...".
-- `reserve` is the space kept free on the right (number, or function(width) -> number).
function Control:_fitHeader(label, reserve, opts)
	opts = opts or {}
	local window = self._ctx.Window
	self._fitter = Fit.bind({
		label = label,
		container = self.Header,
		base = self.Header.Size.Y.Offset,
		reserve = reserve,
		padX = opts.padX,
		sizeLabel = opts.sizeLabel,
		watch = opts.watch,
		maid = self._maid,
		scale = function()
			return window:_textScale()
		end,
	})
	return self._fitter
end

function Control:_addName(reserve, opts)
	local fixed = type(reserve) == "number" and reserve or 0
	local label = Create.new("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -fixed, 1, 0),
		Text = self._name,
		Parent = self.Header,
	})
	self._ctx.Theme:Bind(label, {
		Font = function(theme)
			return theme.Font.Medium
		end,
		TextSize = function(theme)
			return theme.TextSize.Body
		end,
	})
	self._nameLabel = label
	self:_onRender(function(theme)
		label.TextColor3 = self._disabled and theme.Colors.TextMuted or theme.Colors.Text
	end)
	opts = opts or {}
	self:_fitHeader(label, reserve or 0, { sizeLabel = true, watch = opts.watch })
	return label
end

function Control:_fire(...)
	local cb = self._cb
	if not cb then
		return
	end
	local name = self._name
	task.spawn(function(...)
		local ok, err = pcall(cb, ...)
		if not ok then
			warn(("[UI] callback for '%s' errored: %s"):format(name, tostring(err)))
		end
	end, ...)
end

function Control:_finish(cfg)
	if cfg.Description then
		self:SetDescription(cfg.Description)
	end
	if cfg.Disabled then
		self:SetDisabled(true)
	end
	return self
end

function Control:_applyVisibility()
	self.Row.Visible = self._visible and not self._filtered
end

function Control:_setFiltered(filtered)
	self._filtered = filtered
	self:_applyVisibility()
end

function Control:_matches(query)
	local haystack = string.lower(self._name .. " " .. (self._desc or ""))
	return string.find(haystack, query, 1, true) ~= nil
end

function Control:_compactHeader()
	self.Header.Size = UDim2.new(1, 0, 0, self._ctx.Touch and 26 or 22)
end

function Control:_addField(height)
	return Create.new("Frame", {
		Name = "Field",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = 2,
		Parent = self.Row,
	})
end

function Control:_style(label, font, size)
	self._ctx.Theme:Bind(label, {
		Font = function(theme)
			return theme.Font[font]
		end,
		TextSize = function(theme)
			return theme.TextSize[size]
		end,
	})
end

function Control:SetName(text)
	self._name = tostring(text)
	if self._nameLabel then
		self._nameLabel.Text = self._name
	end
end

function Control:GetName()
	return self._name
end

function Control:SetDescription(text)
	self._desc = text
	if text == nil or text == "" then
		if self._descLabel then
			self._descLabel:Destroy()
			self._descLabel = nil
		end
		return
	end
	if not self._descLabel then
		local label = Create.new("TextLabel", {
			Name = "Description",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 10,
			Parent = self.Row,
		})
		Create.Padding(label, 0, 0, 0, 4)
		self._ctx.Theme:Text(label, "TextDim", "Regular", "Small")
		self._descLabel = label
	end
	self._descLabel.Text = tostring(text)
end

function Control:SetDisabled(disabled)
	self._disabled = disabled and true or false
	self:_rerender(true)
end

function Control:IsDisabled()
	return self._disabled
end

function Control:SetVisible(visible)
	self._visible = visible and true or false
	self:_applyVisibility()
end

function Control:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._card:_unregister(self)
	self._maid:Destroy()
	self.Row:Destroy()
end

return Control
