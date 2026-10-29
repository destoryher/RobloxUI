local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Tween = require("util/tween")

local Button = setmetatable({}, { __index = Control })
Button.__index = Button

local STYLES = { Default = true, Accent = true, Danger = true }

function Button.new(card, cfg)
	Validate.check("CreateButton", cfg, {
		Name = "string!",
		Callback = "function",
		Description = "string",
		Style = "string",
		Disabled = "boolean",
		Confirm = "boolean|table",
	})
	local style = cfg.Style or "Default"
	if not STYLES[style] then
		error(("[UI] CreateButton: Style must be Default, Accent or Danger (got '%s')"):format(style), 0)
	end

	local self = Control.base(card, cfg, "Button", Button)
	local theme = self._ctx.Theme
	self._hover, self._down = false, false

	local button = Create.new("TextButton", {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		Text = self._name,
		BackgroundTransparency = 0,
		Parent = self.Header,
	})
	theme:Corner(button, "Control")
	Create.Padding(button, 12, 0, 12, 0)
	local stroke = theme:Stroke(button, "Stroke", 1)
	theme:Bind(button, {
		Font = function(t)
			return t.Font.Medium
		end,
		TextSize = function(t)
			return t.TextSize.Body
		end,
	})
	self._nameLabel = button
	-- long button text wraps onto a second line instead of spilling past the edges
	self:_fitHeader(button, 0, { padX = 24 })

	self._maid:Give(button.MouseEnter:Connect(function()
		self._hover = true
		self:_rerender(true)
	end))
	self._maid:Give(button.MouseLeave:Connect(function()
		self._hover, self._down = false, false
		self:_rerender(true)
	end))
	self._maid:Give(button.MouseButton1Down:Connect(function()
		self._down = true
		self:_rerender(true)
	end))
	self._maid:Give(button.MouseButton1Up:Connect(function()
		self._down = false
		self:_rerender(true)
	end))
	self._maid:Give(button.Activated:Connect(function()
		if self._disabled then
			return
		end
		if cfg.Confirm then
			local opts = type(cfg.Confirm) == "table" and cfg.Confirm or {}
			self._ctx.Window:Confirm({
				Title = opts.Title or "Are you sure?",
				Content = opts.Content or ("Run \"" .. self._name .. "\"?"),
				ConfirmText = opts.ConfirmText,
				CancelText = opts.CancelText,
				Danger = opts.Danger ~= nil and opts.Danger or style == "Danger",
				OnConfirm = function()
					self:_fire()
				end,
			})
		else
			self:_fire()
		end
	end))

	self:_onRender(function(t, animate)
		local c = t.Colors
		local bg, text
		if style == "Accent" then
			bg = c.Accent
			text = c.AccentText
		else
			bg = self._down and c.ControlPressed or (self._hover and c.ControlHover or c.Control)
			text = style == "Danger" and c.Danger or c.Text
		end
		local bgTransparency = 0
		if style == "Accent" then
			bgTransparency = self._down and 0.2 or (self._hover and 0.1 or 0)
		end
		if self._disabled then
			text = c.TextMuted
			bgTransparency = 0.4
		end
		button.TextColor3 = text
		stroke.Color = style == "Accent" and c.Accent or c.Stroke
		if animate then
			Tween.play(button, { BackgroundColor3 = bg, BackgroundTransparency = bgTransparency }, t.Animation.Fast)
		else
			button.BackgroundColor3 = bg
			button.BackgroundTransparency = bgTransparency
		end
	end)

	return self:_finish(cfg)
end

function Button:Fire()
	if not self._disabled then
		self:_fire()
	end
end

return Button
