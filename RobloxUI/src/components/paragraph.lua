local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")

local Paragraph = setmetatable({}, { __index = Control })
Paragraph.__index = Paragraph

function Paragraph.new(card, cfg)
	Validate.check("CreateParagraph", cfg, { Title = "string", Content = "string!" })
	cfg.Name = cfg.Title or cfg.Content
	local self = Control.base(card, cfg, "Paragraph", Paragraph)
	local theme = self._ctx.Theme
	self.Header.AutomaticSize = Enum.AutomaticSize.Y
	self.Header.Size = UDim2.new(1, 0, 0, 0)

	local panel = Create.new("Frame", {
		Name = "Panel",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = self.Header,
	})
	theme:Bind(panel, { BackgroundColor3 = "Control" })
	theme:Corner(panel, "Control")
	Create.Padding(panel, 10, 8, 10, 8)
	Create.List(panel, Enum.FillDirection.Vertical, 3)

	local title = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = cfg.Title or "",
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = cfg.Title ~= nil,
		LayoutOrder = 1,
		Parent = panel,
	})
	theme:Text(title, "Text", "Bold", "Body")
	local content = Create.new("TextLabel", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = cfg.Content,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Parent = panel,
	})
	theme:Text(content, "TextDim", "Regular", "Small")
	self._title, self._content = title, content
	return self
end

function Paragraph:SetTitle(text)
	self._title.Text = tostring(text)
	self._title.Visible = text ~= nil and text ~= ""
	self._name = tostring(text)
end

function Paragraph:SetContent(text)
	self._content.Text = tostring(text)
end

function Paragraph:Set(text)
	self:SetContent(text)
end

function Paragraph:Get()
	return self._content.Text
end

return Paragraph
