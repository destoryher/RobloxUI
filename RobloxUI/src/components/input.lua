local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")

local Input = setmetatable({}, { __index = Control })
Input.__index = Input

function Input.new(card, cfg)
	Validate.check("CreateInput", cfg, {
		Name = "string!",
		Default = "string|number",
		Placeholder = "string",
		Numeric = "boolean",
		Description = "string",
		Callback = "function",
		Disabled = "boolean",
		FireDefault = "boolean",
	})
	local self = Control.base(card, cfg, "Input", Input)
	local ctx = self._ctx
	local theme = ctx.Theme
	self._numeric = cfg.Numeric == true
	self._text = cfg.Default ~= nil and tostring(cfg.Default) or ""

	self:_compactHeader()
	self:_addName(0)

	local field = self:_addField(ctx.RowHeight)
	local wrap = Create.new("Frame", { Name = "Box", Size = UDim2.fromScale(1, 1), Parent = field })
	theme:Corner(wrap, "Control")
	local stroke = theme:Stroke(wrap, "Stroke", 1)
	local box = Create.new("TextBox", {
		Name = "Input",
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = self._text,
		PlaceholderText = cfg.Placeholder or "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClipsDescendants = true,
		Parent = wrap,
	})
	self:_style(box, "Medium", "Body")
	theme:Bind(box, { PlaceholderColor3 = "TextMuted" })
	self._box = box

	self._maid:Give(box.Focused:Connect(function()
		self._focused = true
		self:_rerender(true)
	end))
	self._maid:Give(box.FocusLost:Connect(function(enterPressed)
		self._focused = false
		self:_commit(box.Text, enterPressed)
		self:_rerender(true)
	end))

	self:_onRender(function(t)
		local c = t.Colors
		wrap.BackgroundColor3 = self._focused and c.ControlHover or c.Control
		wrap.BackgroundTransparency = self._disabled and 0.4 or 0
		stroke.Color = self._focused and c.Accent or c.Stroke
		box.TextColor3 = self._disabled and c.TextMuted or c.Text
		box.TextEditable = not self._disabled
	end)

	if cfg.FireDefault then
		self:_fire(self:Get(), false)
	end
	return self:_finish(cfg)
end

function Input:_commit(text, enterPressed)
	text = string.match(text, "^%s*(.-)%s*$")
	if self._numeric and text ~= "" and tonumber(text) == nil then
		self._box.Text = self._text
		return
	end
	self._box.Text = text
	if text ~= self._text then
		self._text = text
		self:_fire(self:Get(), enterPressed)
	end
end

function Input:Get()
	if self._numeric then
		return tonumber(self._text)
	end
	return self._text
end

function Input:Set(value, silent)
	local text = value == nil and "" or tostring(value)
	if self._numeric and text ~= "" and tonumber(text) == nil then
		error("[UI] Input:Set expects a number for a numeric input", 0)
	end
	self._box.Text = text
	if text ~= self._text then
		self._text = text
		if not silent then
			self:_fire(self:Get(), false)
		end
	end
end

function Input:SetPlaceholder(text)
	self._box.PlaceholderText = tostring(text)
end

return Input
