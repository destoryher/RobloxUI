local Control = require("core/control")
local Create = require("util/create")
local Validate = require("util/validate")
local Tween = require("util/tween")
local Popup = require("core/popup")

local Dropdown = setmetatable({}, { __index = Control })
Dropdown.__index = Dropdown

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

function Dropdown.new(card, cfg)
	Validate.check("CreateDropdown", cfg, {
		Name = "string!",
		Options = "table!",
		Multi = "boolean",
		Default = "string|number|table",
		Placeholder = "string",
		Search = "boolean",
		Description = "string",
		Callback = "function",
		Disabled = "boolean",
		FireDefault = "boolean",
	})
	local self = Control.base(card, cfg, "Dropdown", Dropdown)
	local ctx = self._ctx
	local theme = ctx.Theme
	self._multi = cfg.Multi == true
	self._options = toList(cfg.Options)
	self._selected = {}
	self._placeholder = cfg.Placeholder or (self._multi and "None" or "Select...")
	self._searchable = cfg.Search
	self._hover, self._open = false, false

	self:_compactHeader()
	self:_addName(0)

	local field = self:_addField(ctx.RowHeight)
	local button = Create.new("TextButton", {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		Parent = field,
	})
	theme:Corner(button, "Control")
	local stroke = theme:Stroke(button, "Stroke", 1)
	local summary = Create.new("TextLabel", {
		Name = "Summary",
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -38, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	})
	self:_style(summary, "Medium", "Body")
	local chevron = Create.new("TextLabel", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -18, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		Text = "\u{203A}",
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = 90,
		Parent = button,
	})
	self:_style(chevron, "Bold", "Title")
	self._button = button

	self._maid:Give(button.MouseEnter:Connect(function()
		self._hover = true
		self:_rerender(true)
	end))
	self._maid:Give(button.MouseLeave:Connect(function()
		self._hover = false
		self:_rerender(true)
	end))
	self._maid:Give(button.Activated:Connect(function()
		if self._open then
			self._popup.Close()
		else
			self:_openPopup()
		end
	end))

	self:_applyValue(cfg.Default)
	self:_onRender(function(t, animate)
		local c = t.Colors
		local text, empty = self:_summaryText()
		summary.Text = text
		summary.TextColor3 = (empty or self._disabled) and c.TextMuted or c.Text
		chevron.TextColor3 = c.TextDim
		stroke.Color = self._open and c.Accent or c.Stroke
		button.BackgroundTransparency = self._disabled and 0.4 or 0
		local bg = (self._hover or self._open) and c.ControlHover or c.Control
		local rotation = self._open and -90 or 90
		if animate then
			Tween.play(button, { BackgroundColor3 = bg }, t.Animation.Fast)
			Tween.play(chevron, { Rotation = rotation }, t.Animation.Fast)
		else
			button.BackgroundColor3 = bg
			chevron.Rotation = rotation
		end
	end)

	if cfg.FireDefault then
		self:_fire(self:Get())
	end
	return self:_finish(cfg)
end

function Dropdown:_selectedList()
	local out = {}
	for _, option in ipairs(self._options) do
		if self._selected[option] then
			out[#out + 1] = option
		end
	end
	return out
end

function Dropdown:_summaryText()
	local list = self:_selectedList()
	if #list == 0 then
		return self._placeholder, true
	end
	if #list > 3 then
		return #list .. " selected", false
	end
	return table.concat(list, ", "), false
end

function Dropdown:_applyValue(value)
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

function Dropdown:_refresh()
	self:_rerender(true)
	self:_paintRows()
end

function Dropdown:Get()
	local list = self:_selectedList()
	if self._multi then
		return list
	end
	return list[1]
end

function Dropdown:Set(value, silent)
	if self:_applyValue(value) then
		self:_refresh()
		if not silent then
			self:_fire(self:Get())
		end
	end
end

function Dropdown:Clear(silent)
	self:Set(nil, silent)
end

function Dropdown:SelectAll(silent)
	if self._multi then
		self:Set(self._options, silent)
	end
end

function Dropdown:SetOptions(options, silent)
	if type(options) ~= "table" then
		error("[UI] Dropdown:SetOptions expects a table of options", 0)
	end
	local keep = {}
	for option in pairs(self._selected) do
		keep[#keep + 1] = option
	end
	self._options = toList(options)
	local changed = self:_applyValue(keep)
	self:_rerender(true)
	if self._list then
		self:_buildRows()
	end
	if changed and not silent then
		self:_fire(self:Get())
	end
end

function Dropdown:_pick(option)
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
		if self._popup then
			self._popup.Close()
		end
	end
end

function Dropdown:_paintRows()
	if not self._rowRefs then
		return
	end
	local c = self._ctx.Theme:Get().Colors
	for option, ref in pairs(self._rowRefs) do
		local on = self._selected[option] == true
		ref.Label.TextColor3 = on and c.Accent or c.Text
		if self._multi then
			ref.Row.BackgroundColor3 = c.ControlHover
			ref.Row.BackgroundTransparency = ref.hover and 0.5 or 1
			ref.Box.BackgroundColor3 = on and c.Accent or c.Control
			ref.Stroke.Color = on and c.Accent or c.TextMuted
			ref.Inner.Visible = on
			ref.Inner.BackgroundColor3 = c.AccentText
		else
			ref.Row.BackgroundColor3 = on and c.Control or c.ControlHover
			ref.Row.BackgroundTransparency = on and 0 or (ref.hover and 0.5 or 1)
		end
	end
end

function Dropdown:_filterRows(text)
	local query = string.lower(string.match(text or "", "^%s*(.-)%s*$"))
	self._query = query
	for option, ref in pairs(self._rowRefs or {}) do
		ref.Row.Visible = query == "" or string.find(string.lower(option), query, 1, true) ~= nil
	end
end

function Dropdown:_makeRow(index, option)
	local ctx = self._ctx
	local theme = ctx.Theme
	local rowH = ctx.Touch and 40 or 30
	local row = Create.new("TextButton", {
		Name = option,
		Size = UDim2.new(1, 0, 0, rowH),
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Parent = self._list,
	})
	theme:Corner(row, "Control")
	local label = Create.new("TextLabel", {
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, self._multi and -42 or -20, 1, 0),
		Text = option,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	self:_style(label, "Medium", "Body")
	local ref = { Row = row, Label = label, hover = false }
	if self._multi then
		local box = Create.new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			Parent = row,
		})
		Create.Corner(box, 5)
		ref.Stroke = Create.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1, Parent = box })
		ref.Inner = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(8, 8),
			Parent = box,
		})
		Create.Corner(ref.Inner, 2)
		ref.Box = box
	end
	if self._query and self._query ~= "" and not string.find(string.lower(option), self._query, 1, true) then
		row.Visible = false
	end
	row.Activated:Connect(function()
		self:_pick(option)
	end)
	row.MouseEnter:Connect(function()
		ref.hover = true
		self:_paintRows()
	end)
	row.MouseLeave:Connect(function()
		ref.hover = false
		self:_paintRows()
	end)
	self._rowRefs[option] = ref
end

local ROW_CHUNK = 40

function Dropdown:_buildRows()
	local ctx = self._ctx
	local theme = ctx.Theme
	local list = self._list
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self._rowRefs = {}
	self._buildToken = (self._buildToken or 0) + 1
	local token = self._buildToken
	local options = self._options
	local count = #options

	if count == 0 then
		local empty = Create.new("TextLabel", {
			Size = UDim2.new(1, 0, 0, ctx.Touch and 40 or 30),
			Text = "No options",
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = list,
		})
		theme:Text(empty, "TextMuted", "Regular", "Body")
		return
	end

	for index = 1, math.min(ROW_CHUNK, count) do
		self:_makeRow(index, options[index])
	end
	self:_paintRows()

	if count > ROW_CHUNK then
		task.spawn(function()
			local nextIndex = ROW_CHUNK + 1
			while nextIndex <= count do
				task.wait()
				if self._buildToken ~= token or not self._list or not self._list.Parent then
					return
				end
				for index = nextIndex, math.min(nextIndex + ROW_CHUNK - 1, count) do
					self:_makeRow(index, options[index])
				end
				nextIndex = nextIndex + ROW_CHUNK
				self:_paintRows()
			end
		end)
	end
end

function Dropdown:_openPopup()
	if self._disabled or self._open then
		return
	end
	local ctx = self._ctx
	local theme = ctx.Theme
	local rowH = ctx.Touch and 40 or 30
	local count = #self._options
	local showSearch = self._searchable
	if showSearch == nil then
		showSearch = count > 8
	end
	local headerH = showSearch and 42 or 0
	local footerH = self._multi and 46 or 0
	local listH = math.min(math.max(count, 1) * (rowH + 2) + 10, 230)

	local popup = Popup.open(ctx.Window, self._button, {
		Height = headerH + listH + footerH,
		OnClose = function()
			self._open = false
			self._buildToken = (self._buildToken or 0) + 1
			self._popup, self._list, self._rowRefs = nil, nil, nil
			self:_rerender(true)
		end,
	})
	self._popup, self._open = popup, true
	self._query = ""

	local body = popup.Body
	if showSearch then
		local box = Create.new("TextBox", {
			Name = "Search",
			Position = UDim2.new(0, 8, 0, 7),
			Size = UDim2.new(1, -16, 0, headerH - 14),
			BackgroundTransparency = 0,
			Text = "",
			PlaceholderText = "Search...",
			Parent = body,
		})
		theme:Bind(box, { BackgroundColor3 = "Control", TextColor3 = "Text", PlaceholderColor3 = "TextMuted" })
		self:_style(box, "Regular", "Body")
		theme:Corner(box, "Control")
		Create.Padding(box, 10, 0, 10, 0)
		popup.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
			self:_filterRows(box.Text)
		end))
	end

	local list = Create.new("ScrollingFrame", {
		Name = "Options",
		Position = UDim2.new(0, 0, 0, headerH),
		Size = UDim2.new(1, 0, 0, listH),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = body,
	})
	theme:Bind(list, { ScrollBarImageColor3 = "TextMuted" })
	Create.Padding(list, 6, 4, 6, 4)
	Create.List(list, Enum.FillDirection.Vertical, 2)
	self._list = list
	self:_buildRows()
	popup.Maid:Give(theme:Watch(function()
		self:_paintRows()
	end))

	if self._multi then
		local footer = Create.new("Frame", {
			Name = "Footer",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, footerH),
			Parent = body,
		})
		local line = Create.new("Frame", { Size = UDim2.new(1, 0, 0, 1), Parent = footer })
		theme:Bind(line, { BackgroundColor3 = "Divider" })
		local function small(text, x, action)
			local button = Create.new("TextButton", {
				Name = text,
				Position = UDim2.new(x, x == 0 and 8 or 4, 0, 8),
				Size = UDim2.new(0.5, -12, 1, -16),
				Text = text,
				BackgroundTransparency = 0,
				Parent = footer,
			})
			theme:Bind(button, { BackgroundColor3 = "Control", TextColor3 = "Text" })
			self:_style(button, "Medium", "Small")
			theme:Corner(button, "Control")
			button.Activated:Connect(action)
		end
		small("Select all", 0, function()
			self:SelectAll()
		end)
		small("Clear", 0.5, function()
			self:Clear()
		end)
	end
end

function Dropdown:Destroy()
	if self._popup then
		self._popup.Close()
	end
	Control.Destroy(self)
end

return Dropdown
