local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Tween = require("util/tween")

local Chips = setmetatable({}, { __index = Control })
Chips.__index = Chips

local function toList(options)
	local list, seen = {}, {}
	for _, option in ipairs(options) do
		local text = tostring(option)
		if not seen[text] then
			seen[text] = true
			list[#list + 1] = text
		end
	end
	return list
end

local function sameSet(a, b)
	for key in pairs(a) do
		if not b[key] then
			return false
		end
	end
	for key in pairs(b) do
		if not a[key] then
			return false
		end
	end
	return true
end

function Chips.new(card, cfg)
	Validate.check("CreateChips", cfg, {
		Name = "string",
		Options = "table!",
		Multi = "boolean",
		Default = "string|number|table",
		Description = "string",
		Callback = "function",
		Disabled = "boolean",
		FireDefault = "boolean",
	})
	local self = Control.base(card, cfg, "Chips", Chips)
	local ctx = self._ctx
	self._multi = cfg.Multi == true
	self._options = toList(cfg.Options)
	self._selected = {}
	self._refs = {}

	if cfg.Name then
		self:_compactHeader()
		self:_addName(0)
	else
		self.Header.Size = UDim2.new(1, 0, 0, 0)
		self.Header.Visible = false
	end

	local field = Create.new("Frame", {
		Name = "Field",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = self.Row,
	})
	local list = Create.List(field, Enum.FillDirection.Horizontal, 6)
	list.Wraps = true
	self._field = field

	self:_applyValue(cfg.Default)
	self:_build()
	self:_onRender(function(t, animate)
		self:_paint(t, animate)
	end)

	if cfg.FireDefault then
		self:_fire(self:Get())
	end
	return self:_finish(cfg)
end

function Chips:_build()
	for _, child in ipairs(self._field:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self._refs = {}
	local height = self._ctx.Touch and 34 or 28
	for index, option in ipairs(self._options) do
		local chip = Create.new("TextButton", {
			Name = option,
			Size = UDim2.new(0, 0, 0, height),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = option,
			BackgroundTransparency = 0,
			LayoutOrder = index,
			Parent = self._field,
		})
		Create.Padding(chip, 12, 0, 12, 0)
		Create.Corner(chip, UDim.new(1, 0))
		local stroke = Create.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1, Parent = chip })
		self:_style(chip, "Medium", "Body")
		local ref = { Button = chip, Stroke = stroke, hover = false }
		self._refs[option] = ref
		chip.Activated:Connect(function()
			if not self._disabled then
				self:_pick(option)
			end
		end)
		chip.MouseEnter:Connect(function()
			ref.hover = true
			self:_rerender(true)
		end)
		chip.MouseLeave:Connect(function()
			ref.hover = false
			self:_rerender(true)
		end)
	end
end

function Chips:_paint(t, animate)
	local c = t.Colors
	for option, ref in pairs(self._refs) do
		local on = self._selected[option] == true
		local bg = on and c.Accent or (ref.hover and c.ControlHover or c.Control)
		local text = on and c.AccentText or (ref.hover and c.Text or c.TextDim)
		ref.Button.TextColor3 = self._disabled and c.TextMuted or text
		ref.Stroke.Color = on and c.Accent or c.Stroke
		ref.Button.BackgroundTransparency = self._disabled and 0.5 or 0
		if animate then
			Tween.play(ref.Button, { BackgroundColor3 = bg }, t.Animation.Fast)
		else
			ref.Button.BackgroundColor3 = bg
		end
	end
end

function Chips:_selectedList()
	local out = {}
	for _, option in ipairs(self._options) do
		if self._selected[option] then
			out[#out + 1] = option
		end
	end
	return out
end

function Chips:_applyValue(value)
	local wanted = {}
	if type(value) == "table" then
		for _, entry in ipairs(value) do
			wanted[tostring(entry)] = true
		end
	elseif value ~= nil then
		wanted[tostring(value)] = true
	end
	local valid, count = {}, 0
	for _, option in ipairs(self._options) do
		if wanted[option] and (self._multi or count == 0) then
			valid[option] = true
			count = count + 1
		end
	end
	local changed = not sameSet(valid, self._selected)
	self._selected = valid
	return changed
end

function Chips:Get()
	local list = self:_selectedList()
	if self._multi then
		return list
	end
	return list[1]
end

function Chips:Set(value, silent)
	if self:_applyValue(value) then
		self:_rerender(true)
		if not silent then
			self:_fire(self:Get())
		end
	end
end

function Chips:Clear(silent)
	self:Set(nil, silent)
end

function Chips:SelectAll(silent)
	if self._multi then
		self:Set(self._options, silent)
	end
end

function Chips:SetOptions(options, silent)
	if type(options) ~= "table" then
		error("[UI] Chips:SetOptions expects a table of options", 0)
	end
	local keep = {}
	for option in pairs(self._selected) do
		keep[#keep + 1] = option
	end
	self._options = toList(options)
	local changed = self:_applyValue(keep)
	self:_build()
	self:_rerender(false)
	if changed and not silent then
		self:_fire(self:Get())
	end
end

function Chips:_pick(option)
	if self._multi then
		local out, found = {}, false
		for _, existing in ipairs(self:_selectedList()) do
			if existing == option then
				found = true
			else
				out[#out + 1] = existing
			end
		end
		if not found then
			out[#out + 1] = option
		end
		self:Set(out)
	else
		self:Set(option)
	end
end

return Chips
