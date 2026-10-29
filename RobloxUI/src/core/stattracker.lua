-- Stat tracker: a Stats tab inside the window plus a floating, draggable overlay that shows while the
-- window is minimized (same look as the keybind list). Tracks any number: leaderstats, attributes,
-- value objects, text labels, a function, or counters the script bumps itself.
local Create = require("util/create")
local Tween = require("util/tween")
local Drag = require("util/drag")
local Maid = require("util/maid")
local Validate = require("util/validate")
local Format = require("util/format")
local Fit = require("util/fit")
local Services = require("util/services")

local Players = Services.Players

local Tracker = {}
Tracker.__index = Tracker

local Stat = {}
Stat.__index = Stat

local DEFAULT_WIDTH = 230
local SHOW_WHEN = { Minimized = true, Hidden = true, Closed = true, Always = true }
local FORMATS = { Compact = true, Number = true, Money = true, Time = true, Clock = true, Percent = true, Text = true }
local MODES = { Net = true, Earned = true }
local RATE_AFTER = 15

local function shouldShow(mode, state)
	if mode == "Always" then
		return true
	end
	if mode == "Minimized" then
		return state == "minimized"
	end
	if mode == "Hidden" then
		return state == "hidden"
	end
	return state ~= "open"
end

local function styleText(theme, label, font, size)
	theme:Bind(label, {
		Font = function(t)
			return t.Font[font]
		end,
		TextSize = function(t)
			return t.TextSize[size]
		end,
	})
end

local function localPlayer()
	return Players and Players.LocalPlayer
end

local function findChild(parent, name)
	if not parent then
		return nil
	end
	local child = parent:FindFirstChild(name)
	if child then
		return child
	end
	local wanted = string.lower(name)
	for _, item in ipairs(parent:GetChildren()) do
		if string.lower(item.Name) == wanted then
			return item
		end
	end
	return nil
end

local function readInstance(inst)
	if typeof(inst) ~= "Instance" then
		return nil
	end
	if inst:IsA("ValueBase") then
		return inst.Value
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		return inst.Text
	end
	return nil
end

-- Builds the function that reads a stat's current value, from whichever source the config names.
local function makeReader(cfg)
	if cfg.Get then
		return cfg.Get
	end
	if cfg.Leaderstat then
		local name = cfg.Leaderstat
		return function()
			local player = localPlayer()
			return readInstance(findChild(player and player:FindFirstChild("leaderstats"), name))
		end
	end
	if cfg.Attribute then
		local name, target = cfg.Attribute, cfg.Instance
		return function()
			local inst = target
			if type(inst) == "function" then
				inst = inst()
			elseif inst == nil then
				inst = localPlayer()
			end
			if typeof(inst) ~= "Instance" then
				return nil
			end
			return inst:GetAttribute(name)
		end
	end
	if cfg.Source then
		local source = cfg.Source
		return function()
			local inst = source
			if type(inst) == "function" then
				inst = inst()
			end
			return readInstance(inst)
		end
	end
	return nil
end

-- The style used for gains and rates: time stays time, everything else is shown compact.
local DELTA_STYLE = { Time = "Time", Clock = "Time", Money = "Money", Percent = "Percent", Number = "Number" }

local function deltaStyle(style)
	return type(style) == "string" and DELTA_STYLE[style] or "Compact"
end

-- ----------------------------------------------------------------- stat

function Stat:_read()
	if not self._reader then
		return
	end
	local ok, raw = pcall(self._reader)
	if ok and raw ~= nil then
		self:_push(raw)
	end
end

-- Feeds a new reading in. Numbers count toward the session gain while the tracker runs.
function Stat:_push(raw)
	self._raw = raw
	local number = type(raw) ~= "boolean" and Format.parse(raw) or nil
	if self._format == "Text" or number == nil then
		self._number = nil
		return
	end
	local last = self._number
	self._number = number
	if last == nil or self._tracker._paused then
		return
	end
	local delta = number - last
	if delta ~= 0 then
		self._net = self._net + delta
		if delta > 0 then
			self._earned = self._earned + delta
		end
	end
end

function Stat:_valueText()
	if self._number ~= nil and self._format ~= "Text" then
		return Format.value(self._number, self._format, self._decimals, self._prefix, self._suffix)
	end
	if self._raw == nil then
		return "--"
	end
	return (self._prefix or "") .. tostring(self._raw) .. (self._suffix or "")
end

function Stat:GetGained()
	return self._mode == "Earned" and self._earned or self._net
end

-- Average gain per hour over the session (nil until there is enough time to say).
function Stat:GetRate()
	local elapsed = self._tracker:GetElapsed()
	if elapsed < RATE_AFTER then
		return nil
	end
	return self:GetGained() / elapsed * 3600
end

function Stat:_texts()
	local style = deltaStyle(self._format)
	local numeric = self._number ~= nil
	local out = { value = self:_valueText() }
	if not numeric then
		return out
	end
	if self._showGain then
		local gained = self:GetGained()
		local sign = gained > 0 and "+" or (gained < 0 and "-" or "+")
		out.gain = sign .. Format.value(math.abs(gained), style, self._decimals)
		out.gainSign = gained > 0 and 1 or (gained < 0 and -1 or 0)
	end
	local rate = self:GetRate()
	if self._showRate then
		out.rate = rate and (Format.value(rate, style, self._decimals) .. "/hr") or "--/hr"
	end
	if self._goal then
		local fraction = math.clamp(self._number / self._goal, 0, 1)
		out.fraction = fraction
		local eta
		if self._number >= self._goal then
			eta = "Goal reached"
		elseif rate and rate > 0 then
			eta = "Goal in " .. Format.duration((self._goal - self._number) / rate * 3600)
		else
			eta = string.format("%d%% of goal", math.floor(fraction * 100))
		end
		out.eta = eta
	end
	return out
end

function Stat:_render()
	if self._destroyed then
		return
	end
	local texts = self:_texts()
	local tracker = self._tracker

	if self._control then
		self._control:Set(texts.value)
		local parts = {}
		if texts.gain then
			parts[#parts + 1] = texts.gain .. " this session"
		end
		if texts.rate and self._number ~= nil then
			parts[#parts + 1] = texts.rate
		end
		local desc = table.concat(parts, "  \u{00B7}  ")
		if desc ~= self._lastDesc then
			self._lastDesc = desc
			self._control:SetDescription(desc ~= "" and desc or nil)
		end
	end
	if self._progress and self._goal then
		self._progress:Set(math.min(self._number or 0, self._goal), texts.eta or "")
	end

	local hud = self._hud
	if hud then
		if hud.value.Text ~= texts.value then
			hud.value.Text = texts.value
		end
		local left = texts.gain or ""
		local right = texts.eta or texts.rate or ""
		if hud.gain.Text ~= left then
			hud.gain.Text = left
		end
		if hud.rate.Text ~= right then
			hud.rate.Text = right
		end
		hud.sub.Visible = left ~= "" or right ~= ""
		hud.bar.Visible = texts.fraction ~= nil
		if texts.fraction then
			hud.fill.Size = UDim2.fromScale(texts.fraction, 1)
		end
		if hud.sign ~= texts.gainSign then
			hud.sign = texts.gainSign
			tracker:_paintRowColors(self)
		end
	end
end

function Stat:Get()
	return self._number ~= nil and self._number or self._raw
end

-- For counters and script-driven stats: set the current value.
function Stat:Set(value)
	self:_push(value)
	self:_render()
end

-- For counters: add to the current value (default 1). Counts toward the session gain.
function Stat:Increment(amount)
	self:_push((self._number or 0) + (amount or 1))
	self:_render()
end

function Stat:SetGoal(goal)
	if goal ~= nil and (type(goal) ~= "number" or goal <= 0) then
		error("[UI] Stat:SetGoal expects a positive number or nil", 0)
	end
	self._goal = goal
	if goal and self._card and not self._progress then
		self._progress = self._card:CreateProgress({ Name = self._name .. " goal", Min = 0, Max = goal })
	elseif goal and self._progress then
		self._progress:SetRange(0, goal)
	end
	if self._progress then
		self._progress:SetVisible(goal ~= nil and self._visible)
	end
	self:_render()
end

function Stat:SetName(text)
	self._name = tostring(text)
	if self._control then
		self._control:SetName(self._name)
	end
	if self._hud then
		self._hud.name.Text = self._name
	end
end

-- Start counting the gain again from the current value.
function Stat:Reset()
	self._net, self._earned = 0, 0
	self:_render()
end

function Stat:SetVisible(visible)
	self._visible = visible and true or false
	if self._control then
		self._control:SetVisible(self._visible)
	end
	if self._progress then
		self._progress:SetVisible(self._visible and self._goal ~= nil)
	end
	if self._hud then
		self._hud.row.Visible = self._visible and self._showInHud
	end
	self._tracker:_sync()
end

-- Show or hide this stat in the floating overlay (it stays in the tab).
function Stat:SetHud(show)
	self._showInHud = show and true or false
	if self._hud then
		self._hud.row.Visible = self._visible and self._showInHud
	end
	self._tracker:_sync()
end

function Stat:Remove()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._maid:Destroy()
	if self._control then
		self._control:Destroy()
	end
	if self._progress then
		self._progress:Destroy()
	end
	if self._hud then
		self._hud.row:Destroy()
	end
	self._tracker:_forget(self)
end

Stat.Destroy = Stat.Remove

-- -------------------------------------------------------------- tracker

function Tracker:_nextOrder()
	self._order = self._order + 1
	return self._order
end

function Tracker:_scaleFn()
	local window = self._window
	return function()
		if self._scale.Scale < 0.999 then
			return nil
		end
		return math.max(window._uiScale, 0.01)
	end
end

function Tracker:_buildRow(stat)
	local window = self._window
	local theme = window.Theme
	local touch = window._ctx.Touch
	local maid = stat._maid

	local row = Create.new("Frame", {
		Name = "Stat",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:_nextOrder(),
		Visible = stat._showInHud,
		Parent = self._body,
	})
	Create.List(row, Enum.FillDirection.Vertical, 1)
	Create.Padding(row, 8, 3, 8, 3)

	local line = Create.new("Frame", {
		Name = "Line",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, touch and 22 or 20),
		LayoutOrder = 1,
		Parent = row,
	})
	local value = Create.new("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 60, 1, 0),
		Text = "--",
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = line,
	})
	styleText(theme, value, "Bold", "Body")
	local name = Create.new("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -70, 1, 0),
		Text = stat._name,
		Parent = line,
	})
	styleText(theme, name, "Medium", "Small")
	Fit.bind({
		label = name,
		container = line,
		base = touch and 22 or 20,
		sizeLabel = true,
		watch = { value },
		maid = maid,
		scale = self:_scaleFn(),
		reserve = function(width)
			local needed = Fit.width(value.Text, value.TextSize, value.Font) + 2
			local valueW = math.min(needed, math.floor(width * 0.6))
			value.Size = UDim2.new(0, valueW, 1, 0)
			return valueW + 10
		end,
	})

	local sub = Create.new("Frame", {
		Name = "Sub",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 2,
		Visible = false,
		Parent = row,
	})
	local gain = Create.new("TextLabel", {
		Name = "Gain",
		Size = UDim2.new(0.5, -4, 1, 0),
		Text = "",
		Parent = sub,
	})
	styleText(theme, gain, "Medium", "Small")
	local rate = Create.new("TextLabel", {
		Name = "Rate",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.5, -4, 1, 0),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = sub,
	})
	styleText(theme, rate, "Regular", "Small")

	local barWrap = Create.new("Frame", {
		Name = "Goal",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 7),
		LayoutOrder = 3,
		Visible = false,
		Parent = row,
	})
	local bar = Create.new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 3),
		Parent = barWrap,
	})
	Create.Corner(bar, UDim.new(1, 0))
	local fill = Create.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), Parent = bar })
	Create.Corner(fill, UDim.new(1, 0))

	stat._hud = {
		row = row,
		name = name,
		value = value,
		sub = sub,
		gain = gain,
		rate = rate,
		bar = barWrap,
		fill = fill,
	}
	maid:Give(row)
	maid:Give(theme:Watch(function(t)
		bar.BackgroundColor3 = t.Colors.Control
		fill.BackgroundColor3 = t.Colors.Accent
		self:_paintRowColors(stat)
	end))
end

function Tracker:_paintRowColors(stat)
	local hud = stat._hud
	local c = self._window.Theme:Get().Colors
	hud.name.TextColor3 = c.TextDim
	hud.value.TextColor3 = c.Text
	hud.rate.TextColor3 = c.TextMuted
	local sign = hud.sign or 0
	hud.gain.TextColor3 = sign > 0 and c.Success or (sign < 0 and c.Danger or c.TextMuted)
end

function Tracker:_cardFor(group)
	if not self._tab then
		return nil
	end
	local card = self._cards[group]
	if not card then
		card = self._tab:CreateCard({ Name = group })
		self._cards[group] = card
	end
	return card
end

-- Adds a tracked stat. Source (pick one): Leaderstat = "Coins" | Attribute = "Level" (+ Instance) |
-- Source = ValueObject or TextLabel (or a function returning one) | Get = function() return value end.
-- With no source it is a counter you drive with :Set / :Increment.
function Tracker:Add(cfg)
	if self._destroyed then
		return nil
	end
	Validate.check("StatTracker:Add", cfg, {
		Name = "string!",
		Id = "string",
		Group = "string",
		Leaderstat = "string",
		Attribute = "string",
		Instance = "Instance|function",
		Source = "Instance|function",
		Get = "function",
		Value = "number|string",
		Format = "string|function",
		Decimals = "number",
		Prefix = "string",
		Suffix = "string",
		Mode = "string",
		Goal = "number",
		Gain = "boolean",
		Rate = "boolean",
		Hud = "boolean",
		Tab = "boolean",
	})
	local format = cfg.Format or "Compact"
	if type(format) == "string" and not FORMATS[format] then
		error(("[UI] StatTracker:Add: Format must be Compact, Number, Money, Time, Clock, Percent, Text or a function (got '%s')"):format(format), 0)
	end
	local mode = cfg.Mode or "Net"
	if not MODES[mode] then
		error("[UI] StatTracker:Add: Mode must be Net or Earned", 0)
	end
	local id = cfg.Id or cfg.Name
	if self._byId[id] then
		error(("[UI] StatTracker:Add: a stat with Id '%s' already exists"):format(id), 0)
	end

	local stat = setmetatable({}, Stat)
	stat._tracker = self
	stat._maid = Maid.new()
	stat.Id = id
	stat._name = cfg.Name
	stat._reader = makeReader(cfg)
	stat._format = format
	stat._decimals = cfg.Decimals
	stat._prefix, stat._suffix = cfg.Prefix, cfg.Suffix
	stat._mode = mode
	stat._goal = cfg.Goal
	stat._showGain = cfg.Gain ~= false and format ~= "Text"
	stat._showRate = cfg.Rate ~= false and format ~= "Text"
	stat._showInHud = cfg.Hud ~= false
	stat._visible = true
	stat._net, stat._earned = 0, 0

	if cfg.Tab ~= false then
		local card = self:_cardFor(cfg.Group or "Tracked")
		if card then
			stat._card = card
			stat._control = card:CreateStat({ Name = cfg.Name, Value = "--" })
			if stat._goal then
				stat._progress = card:CreateProgress({ Name = cfg.Name .. " goal", Min = 0, Max = stat._goal })
			end
		end
	end
	self:_buildRow(stat)

	self._stats[#self._stats + 1] = stat
	self._byId[id] = stat
	if cfg.Value ~= nil then
		stat:_push(cfg.Value)
	end
	stat:_read()
	stat:_render()
	self:_sync()
	return stat
end

-- Shortcuts for common sources.
function Tracker:AddLeaderstat(name, cfg)
	cfg = cfg or {}
	cfg.Name = cfg.Name or name
	cfg.Leaderstat = name
	return self:Add(cfg)
end

function Tracker:AddAttribute(name, cfg)
	cfg = cfg or {}
	cfg.Name = cfg.Name or name
	cfg.Attribute = name
	return self:Add(cfg)
end

function Tracker:AddCounter(name, cfg)
	cfg = cfg or {}
	cfg.Name = cfg.Name or name
	cfg.Value = cfg.Value or 0
	cfg.Format = cfg.Format or "Number"
	return self:Add(cfg)
end

-- Tracks every value in the player's leaderstats, including ones the game adds later.
-- opts: Group, Exclude = { "Name", ... }, Format, Hud
function Tracker:AddLeaderstats(opts)
	opts = opts or {}
	local exclude = {}
	for _, name in ipairs(opts.Exclude or {}) do
		exclude[string.lower(name)] = true
	end
	local function addValue(child)
		if self._destroyed or not child:IsA("ValueBase") or exclude[string.lower(child.Name)] then
			return
		end
		if self._byId["leaderstat:" .. child.Name] then
			return
		end
		local isText = child:IsA("StringValue") and Format.parse(child.Value) == nil
		self:Add({
			Name = child.Name,
			Id = "leaderstat:" .. child.Name,
			Group = opts.Group or "Leaderstats",
			Leaderstat = child.Name,
			Format = isText and "Text" or opts.Format,
			Hud = opts.Hud,
		})
	end
	local function watch(folder)
		for _, child in ipairs(folder:GetChildren()) do
			addValue(child)
		end
		self._maid:Give(folder.ChildAdded:Connect(addValue))
	end
	local player = localPlayer()
	if not player then
		return
	end
	local folder = player:FindFirstChild("leaderstats")
	if folder then
		watch(folder)
	else
		local conn
		conn = player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				conn:Disconnect()
				watch(child)
			end
		end)
		self._maid:Give(conn)
	end
end

function Tracker:Get(id)
	return self._byId[id]
end

function Tracker:GetStats()
	return table.clone(self._stats)
end

function Tracker:_forget(stat)
	for i, item in ipairs(self._stats) do
		if item == stat then
			table.remove(self._stats, i)
			break
		end
	end
	if self._byId[stat.Id] == stat then
		self._byId[stat.Id] = nil
	end
	self:_sync()
end

function Tracker:GetElapsed()
	return self._elapsed
end

function Tracker:IsPaused()
	return self._paused
end

function Tracker:Pause()
	if self._paused then
		return
	end
	self._paused = true
	self:_refreshSession()
end

function Tracker:Resume()
	if not self._paused then
		return
	end
	self._paused = false
	self._lastTick = os.clock()
	self:_refreshSession()
end

-- Zero the session clock and every stat's gain.
function Tracker:Reset()
	self._elapsed = 0
	self._lastTick = os.clock()
	for _, stat in ipairs(self._stats) do
		stat._net, stat._earned = 0, 0
		stat:_render()
	end
	self:_refreshSession()
end

-- A short line such as "Farming room 3". Shown under the overlay title and in the Session card.
-- style: Text (default), Accent, Success, Danger, Warning. Pass nil to clear.
function Tracker:SetStatus(text, style)
	self._status = text ~= nil and tostring(text) or nil
	self._statusStyle = style or "Text"
	if self._statusControl then
		self._statusControl:SetVisible(self._status ~= nil)
		self._statusControl:Set(self._status or "")
		if style == "Accent" or style == "Success" or style == "Danger" or style == "Normal" then
			self._statusControl:SetStyle(style)
		else
			self._statusControl:SetStyle("Normal")
		end
	end
	self:_refreshSession()
end

function Tracker:SetTitle(text)
	self._title.Text = string.upper(tostring(text))
end

function Tracker:SetShowWhen(mode)
	if not SHOW_WHEN[mode] then
		error("[UI] StatTracker: ShowWhen must be Minimized, Hidden, Closed or Always", 0)
	end
	self._showWhen = mode
	self:_sync()
end

function Tracker:GetShowWhen()
	return self._showWhen
end

-- Turn the floating overlay on or off (the Stats tab is not affected).
function Tracker:SetVisible(visible)
	self._forceHidden = not visible
	self:_sync()
end

function Tracker:SetCollapsed(collapsed)
	self._collapsed = collapsed and true or false
	self._body.Visible = not self._collapsed
	self._divider.Visible = not self._collapsed
	Tween.play(self._chevron, { Rotation = self._collapsed and 0 or 90 }, self._window.Theme:Get().Animation.Fast)
end

function Tracker:IsCollapsed()
	return self._collapsed
end

function Tracker:GetPosition()
	return self.Pos
end

function Tracker:SetPosition(pos)
	if typeof(pos) ~= "Vector2" then
		error("[UI] StatTracker:SetPosition expects a Vector2", 0)
	end
	self.Pos = pos
	self:_place()
end

function Tracker:_refreshSession()
	local clock = Format.clock(self._elapsed)
	local header = self._paused and ("Paused  " .. clock) or clock
	if self._time.Text ~= header then
		self._time.Text = header
	end
	if self._timeControl then
		self._timeControl:Set(Format.duration(self._elapsed) .. (self._paused and " (paused)" or ""))
	end
	if self._pauseButton then
		self._pauseButton:SetName(self._paused and "Resume Tracking" or "Pause Tracking")
	end
	local status = self._status
	self._statusLabel.Visible = status ~= nil
	if status and self._statusLabel.Text ~= status then
		self._statusLabel.Text = status
	end
	local c = self._window.Theme:Get().Colors
	local style = self._statusStyle
	self._statusLabel.TextColor3 = (style and style ~= "Text" and style ~= "Normal" and c[style]) or c.Text
end

function Tracker:_tick()
	local now = os.clock()
	if not self._paused then
		self._elapsed = self._elapsed + (now - self._lastTick)
	end
	self._lastTick = now
	for _, stat in ipairs(self._stats) do
		stat:_read()
		stat:_render()
	end
	self:_refreshSession()
end

function Tracker:_place()
	if self._destroyed then
		return
	end
	local window = self._window
	local vp = window:_viewport()
	local frame = self.Frame
	local size = frame.AbsoluteSize / (math.max(window._uiScale, 0.01) * math.max(self._scale.Scale, 0.1))
	if size.X < 8 then
		size = Vector2.new(self._width, 80)
	end
	local pos = self.Pos or Vector2.new(vp.X - self._width - 12, vp.Y * 0.22)
	pos = Vector2.new(
		math.clamp(pos.X, 0, math.max(0, vp.X - size.X)),
		math.clamp(pos.Y, 0, math.max(0, vp.Y - size.Y))
	)
	self.Pos = pos
	frame.Position = UDim2.fromOffset(math.floor(pos.X), math.floor(pos.Y))
end

function Tracker:_hasHudStats()
	for _, stat in ipairs(self._stats) do
		if stat._showInHud and stat._visible then
			return true
		end
	end
	return false
end

-- Show or hide the overlay to match the window state (called by Window:_transition).
function Tracker:_sync()
	if self._destroyed then
		return
	end
	local want = self:_hasHudStats() and not self._forceHidden and shouldShow(self._showWhen, self._window._state)
	if want == self._shown then
		return
	end
	self._shown = want
	self._token = self._token + 1
	local token = self._token
	local anim = self._window.Theme:Get().Animation
	if want then
		self.Frame.Visible = true
		self:_place()
		Tween.play(self._scale, { Scale = 1 }, anim.Normal, Enum.EasingStyle.Back)
	else
		local tween = Tween.play(self._scale, { Scale = 0 }, anim.Fast)
		tween.Completed:Connect(function()
			if self._token == token then
				self.Frame.Visible = false
			end
		end)
	end
end

function Tracker:IsShown()
	return self._shown
end

function Tracker:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for index = #self._stats, 1, -1 do
		local stat = self._stats[index]
		stat._destroyed = true
		stat._maid:Destroy()
	end
	self._stats, self._byId = {}, {}
	self._maid:Destroy()
	self.Frame:Destroy()
	self._window:_removeTracker(self)
end

-- The Session card at the top of the tab: clock, status, overlay options, pause and reset.
function Tracker:_buildSessionCard()
	local card = self._tab:CreateCard({ Name = "Session", Highlight = true })
	self._sessionCard = card
	self._timeControl = card:CreateStat({ Name = "Time", Value = "0s" })
	self._statusControl = card:CreateStat({ Name = "Status", Value = "" })
	self._statusControl:SetVisible(false)
	self.Controls = {}
	self.Controls.Overlay = card:CreateToggle({
		Name = "Show Overlay",
		Default = true,
		Description = "A movable stats panel that stays on screen while the menu is closed.",
		Callback = function(on)
			self:SetVisible(on)
		end,
	})
	self.Controls.ShowWhen = card:CreateChips({
		Name = "Overlay Shows",
		Options = { "Minimized", "Closed", "Always" },
		Default = self._showWhen == "Hidden" and "Closed" or self._showWhen,
		Callback = function(choice)
			if choice then
				self:SetShowWhen(choice)
			end
		end,
	})
	self._pauseButton = card:CreateButton({
		Name = "Pause Tracking",
		Callback = function()
			if self._paused then
				self:Resume()
			else
				self:Pause()
			end
		end,
	})
	self.Controls.Pause = self._pauseButton
	self.Controls.Reset = card:CreateButton({
		Name = "Reset Session",
		Confirm = { Title = "Reset session?", Content = "The clock and every gain go back to zero." },
		Callback = function()
			self:Reset()
		end,
	})
end

function Tracker.new(window, cfg)
	Validate.check("CreateStatTracker", cfg, {
		Title = "string",
		Tab = "string|table|boolean",
		TabGroup = "string",
		ShowWhen = "string",
		Interval = "number",
		Width = "number",
		Position = "Vector2",
		Draggable = "boolean",
		SessionCard = "boolean",
	})
	local showWhen = cfg.ShowWhen or "Minimized"
	if not SHOW_WHEN[showWhen] then
		error("[UI] CreateStatTracker: ShowWhen must be Minimized, Hidden, Closed or Always", 0)
	end

	local theme = window.Theme
	local touch = window._ctx.Touch
	local self = setmetatable({}, Tracker)
	self._window = window
	self._maid = Maid.new()
	self._stats, self._byId, self._cards = {}, {}, {}
	self._order = 0
	self._token = 0
	self._shown = false
	self._showWhen = showWhen
	self._collapsed = false
	self._paused = false
	self._elapsed = 0
	self._lastTick = os.clock()
	self._interval = math.max(cfg.Interval or 0.5, 0.1)
	self._width = math.max(170, cfg.Width or DEFAULT_WIDTH)
	self.Pos = cfg.Position
	self.Controls = {}
	window._maid:Give(function()
		self:Destroy()
	end)

	local frame = Create.new("Frame", {
		Name = "StatTracker",
		Size = UDim2.fromOffset(self._width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Visible = false,
		ZIndex = 19,
		Parent = window._root,
	})
	theme:Bind(frame, {
		BackgroundColor3 = "Window",
		BackgroundTransparency = function(t)
			return t.Transparency.Pill
		end,
	})
	theme:Corner(frame, "Window")
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
	Create.List(frame, Enum.FillDirection.Vertical, 0)
	Create.Padding(frame, 8, 6, 8, 8)
	self.Frame = frame
	self._scale = Create.new("UIScale", { Scale = 0, Parent = frame })

	local header = Create.new("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, touch and 32 or 28),
		LayoutOrder = 1,
		Parent = frame,
	})
	local chevron = Create.new("TextLabel", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		Text = "\u{203A}",
		TextXAlignment = Enum.TextXAlignment.Center,
		Rotation = 90,
		Parent = header,
	})
	theme:Text(chevron, "TextMuted", "Bold", "Body")
	local title = Create.new("TextLabel", {
		Name = "Title",
		Position = UDim2.new(0, 20, 0, 0),
		Size = UDim2.new(1, -96, 1, 0),
		Text = string.upper(cfg.Title or "Stats"),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	theme:Text(title, "TextDim", "Bold", "Small")
	local time = Create.new("TextLabel", {
		Name = "Time",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0, 80, 1, 0),
		Text = "0:00",
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	theme:Text(time, "TextMuted", "Medium", "Small")
	self._title, self._time, self._chevron = title, time, chevron

	local statusLabel = Create.new("TextLabel", {
		Name = "Status",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Text = "",
		Visible = false,
		LayoutOrder = 2,
		Parent = frame,
	})
	Create.Padding(statusLabel, 8, 0, 8, 6)
	styleText(theme, statusLabel, "Medium", "Small")
	self._statusLabel = statusLabel

	local divider = Create.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = 3,
		Parent = frame,
	})
	theme:Bind(divider, { BackgroundColor3 = "Divider" })
	self._divider = divider

	local body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = frame,
	})
	Create.List(body, Enum.FillDirection.Vertical, 2)
	Create.Padding(body, 0, 6, 0, 0)
	self._body = body

	-- tap the header to collapse; drag anywhere on the panel to move it
	local start
	local draggable = cfg.Draggable ~= false
	local function bindDrag(handle, onTap)
		Drag.bind(handle, {
			Threshold = 6,
			OnStart = function()
				start = self.Pos
			end,
			OnDelta = function(delta)
				if draggable and start then
					self.Pos = start + delta / window._uiScale
					self:_place()
				end
			end,
			OnEnd = function(moved)
				if not moved and onTap then
					onTap()
				end
			end,
		}, self._maid)
	end
	bindDrag(header, function()
		self:SetCollapsed(not self._collapsed)
	end)
	bindDrag(frame)

	self._maid:Give(frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if frame.Visible then
			self:_place()
		end
	end))
	self._maid:Give(theme:Watch(function()
		for _, stat in ipairs(self._stats) do
			if stat._hud then
				self:_paintRowColors(stat)
			end
		end
		self:_refreshSession()
	end))

	local tabSpec = cfg.Tab
	if tabSpec == nil then
		tabSpec = "Stats"
	end
	if type(tabSpec) == "string" then
		self._tab = window:CreateTab({ Name = tabSpec, Group = cfg.TabGroup })
	elseif type(tabSpec) == "table" then
		self._tab = tabSpec
	end
	if self._tab and cfg.SessionCard ~= false then
		self:_buildSessionCard()
	end

	task.spawn(function()
		while not self._destroyed do
			task.wait(self._interval)
			if self._destroyed then
				break
			end
			local ok, err = pcall(self._tick, self)
			if not ok and not self._warned then
				self._warned = true
				warn("[UI] stat tracker update failed: " .. tostring(err))
			end
		end
	end)

	self:_refreshSession()
	return self
end

return Tracker
