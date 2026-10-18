local Services = require("util/services")
local Create = require("util/create")
local Maid = require("util/maid")
local Tween = require("util/tween")
local Drag = require("util/drag")
local Glyphs = require("util/glyphs")
local Validate = require("util/validate")
local Mount = require("util/mount")
local Env = require("util/env")
local ThemeManager = require("theme/manager")
local Icons = require("core/icons")
local Effects = require("core/effects")
local PushButton = require("core/pushbutton")

local KeyGate = {}
KeyGate.__index = KeyGate

local WIDTH = 380
local HEADER = 66
local STATUS_COLORS = { Info = "TextDim", Error = "Danger", Success = "Success" }

local function trim(text)
	return (string.match(text or "", "^%s*(.-)%s*$"))
end

local function readSaved(file)
	if not (file and isfile and readfile) then
		return nil
	end
	local ok, content = pcall(function()
		if isfile(file) then
			return readfile(file)
		end
		return nil
	end)
	if ok and type(content) == "string" then
		content = trim(content)
		if content ~= "" then
			return content
		end
	end
	return nil
end

local function writeSaved(file, text)
	if file and writefile then
		pcall(writefile, file, text)
	end
end

function KeyGate.new(cfg)
	Validate.check("CreateKeyGate", cfg, {
		Title = "string!",
		Subtitle = "string",
		Icon = "string|number",
		Theme = "string|table",
		Validate = "function",
		Provider = "table",
		Links = "table",
		SaveKey = "boolean",
		FileName = "string",
		Key = "string",
		MaxAttempts = "number",
		Cooldown = "number",
		Timeout = "number",
		OnSuccess = "function",
		OnClose = "function",
		Effects = "string",
	})
	local validate = cfg.Validate or (cfg.Provider and cfg.Provider.Validate)
	if type(validate) ~= "function" then
		error("[UI] CreateKeyGate: provide Validate (a function) or Provider", 0)
	end
	local links = cfg.Links or {}
	for index, link in ipairs(links) do
		Validate.check("CreateKeyGate Links[" .. index .. "]", link, { Name = "string!", Url = "string!" })
	end

	local self = setmetatable({}, KeyGate)
	self._maid = Maid.new()
	self._cfg = cfg
	self._validate = validate
	self._timeout = cfg.Timeout or 20
	self._maxAttempts = cfg.MaxAttempts or 5
	self._cooldown = cfg.Cooldown or 15
	self._fails = 0
	self._waiters = {}
	self._destroyCallbacks = {}
	self._offset = Vector2.new(0, 0)
	self._uiScale = 1
	self._saveEnabled = cfg.SaveKey ~= false
	self._remember = self._saveEnabled
	self._file = cfg.FileName or ((string.gsub(cfg.Title, "[^%w_]", "")) .. "_key.txt")
	self._statusText, self._statusKind = "", "Info"

	local theme = ThemeManager.new(cfg.Theme or "Mono")
	self.Theme = theme
	local input = Services.UserInputService
	local touch = input.TouchEnabled and not input.MouseEnabled

	local gui = Create.new("ScreenGui", {
		Name = "UILibKey",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 1000,
		Enabled = false,
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
	self._root = root
	self._rootScale = Create.new("UIScale", { Parent = root })

	local hasRemember = self._saveEnabled
	local itemHeights = { 44, 32, 44 }
	if hasRemember then
		itemHeights[#itemHeights + 1] = 24
	end
	if #links > 0 then
		itemHeights[#itemHeights + 1] = 40
	end
	local bodyHeight = 14 + 16 + 10 * (#itemHeights - 1)
	for _, height in ipairs(itemHeights) do
		bodyHeight = bodyHeight + height
	end
	self._height = HEADER + bodyHeight

	local main = Create.new("Frame", {
		Name = "KeyGate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, self._height),
		Parent = root,
	})
	theme:Bind(main, { BackgroundColor3 = "Window" })
	theme:Corner(main, "Window")
	theme:Stroke(main, "Stroke", 1)
	local pop = Create.new("UIScale", { Scale = 0.92, Parent = main })
	self._main, self._pop = main, pop
	if cfg.Effects ~= "Lite" then
		Effects.shadow(self, main, pop)
		Effects.windowGlow(self, main)
	end

	local header = Create.new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER),
		Parent = main,
	})
	local icon = Icons.Make(header, cfg.Icon or "mark:cross", cfg.Title, 36, { Tint = false, Corner = 8, Theme = theme })
	icon.Frame.AnchorPoint = Vector2.new(0, 0.5)
	icon.Frame.Position = UDim2.new(0, 16, 0.5, 0)
	if icon.Kind ~= "image" then
		icon.Frame.BackgroundTransparency = 0
		theme:Bind(icon.Frame, { BackgroundColor3 = "Control" })
		Create.Corner(icon.Frame, 8)
		self._maid:Give(theme:Watch(function(t)
			icon:Paint(t.Colors.Accent)
		end))
	end
	local title = Create.new("TextLabel", {
		Position = UDim2.new(0, 64, 0, 15),
		Size = UDim2.new(1, -112, 0, 20),
		Text = cfg.Title,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	theme:Text(title, "Text", "Bold", "Header")
	local subtitle = Create.new("TextLabel", {
		Position = UDim2.new(0, 64, 0, 36),
		Size = UDim2.new(1, -112, 0, 16),
		Text = cfg.Subtitle or "Enter your key to continue",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	theme:Text(subtitle, "TextDim", "Regular", "Small")
	Effects.accentLine(self, main, Vector2.new(0, 0), UDim2.new(0, 16, 0, HEADER - 1), UDim2.new(1, -32, 0, 1))

	local close = Create.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(28, 28),
		Parent = header,
	})
	theme:Corner(close, "Control")
	local _, closeParts = Glyphs.cross(close, 14)
	local closeHover = false
	local function paintClose()
		local c = theme:Get().Colors
		close.BackgroundColor3 = c.ControlHover
		close.BackgroundTransparency = closeHover and 0.35 or 1
		Glyphs.paint(closeParts, closeHover and c.Danger or c.TextMuted)
	end
	self._maid:Give(theme:Watch(paintClose))
	self._maid:Give(close.MouseEnter:Connect(function()
		closeHover = true
		paintClose()
	end))
	self._maid:Give(close.MouseLeave:Connect(function()
		closeHover = false
		paintClose()
	end))
	self._maid:Give(close.Activated:Connect(function()
		self:Destroy()
	end))

	local body = Create.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, HEADER),
		Size = UDim2.new(1, 0, 1, -HEADER),
		Parent = main,
	})
	Create.Padding(body, 16, 14, 16, 16)
	Create.List(body, Enum.FillDirection.Vertical, 10)

	local inputWrap = Create.new("Frame", {
		Name = "Input",
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 1,
		Parent = body,
	})
	theme:Bind(inputWrap, { BackgroundColor3 = "Control" })
	theme:Corner(inputWrap, "Control")
	local inputStroke = theme:Stroke(inputWrap, "Stroke", 1)
	local box = Create.new("TextBox", {
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = "",
		PlaceholderText = "Paste your key",
		ClipsDescendants = true,
		Parent = inputWrap,
	})
	theme:Text(box, "Text", "Medium", "Body")
	theme:Bind(box, { PlaceholderColor3 = "TextMuted" })
	self._box = box
	self._maid:Give(box.Focused:Connect(function()
		inputStroke.Color = theme:Get().Colors.Accent
	end))
	self._maid:Give(box.FocusLost:Connect(function(enterPressed)
		inputStroke.Color = theme:Get().Colors.Stroke
		if enterPressed then
			self:_submit(box.Text)
		end
	end))

	local status = Create.new("TextLabel", {
		Name = "Status",
		Size = UDim2.new(1, 0, 0, 32),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Parent = body,
	})
	theme:Bind(status, {
		Font = function(t)
			return t.Font.Regular
		end,
		TextSize = function(t)
			return t.TextSize.Small
		end,
	})
	self._status = status
	self._maid:Give(theme:Watch(function()
		self:_paintStatus()
	end))

	local verify, verifyApi = PushButton.new(theme, body, "Verify key", "Accent", 3, UDim2.new(1, 0, 0, 44))
	self._verify, self._verifyApi = verify, verifyApi
	self._maid:Give(verify.Activated:Connect(function()
		self:_submit(box.Text)
	end))

	if hasRemember then
		local row = Create.new("TextButton", {
			Name = "Remember",
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 4,
			Parent = body,
		})
		local check = Create.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			Parent = row,
		})
		Create.Corner(check, 4)
		local checkStroke = Create.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1, Parent = check })
		local dot = Create.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(8, 8),
			Parent = check,
		})
		Create.Corner(dot, 2)
		local label = Create.new("TextLabel", {
			Position = UDim2.new(0, 26, 0, 0),
			Size = UDim2.new(1, -26, 1, 0),
			Text = "Remember key on this device",
			Parent = row,
		})
		theme:Text(label, "TextDim", "Regular", "Small")
		local function paintCheck()
			local c = theme:Get().Colors
			check.BackgroundColor3 = self._remember and c.Accent or c.Control
			checkStroke.Color = self._remember and c.Accent or c.TextMuted
			dot.Visible = self._remember
			dot.BackgroundColor3 = c.AccentText
		end
		self._maid:Give(theme:Watch(paintCheck))
		self._maid:Give(row.Activated:Connect(function()
			self._remember = not self._remember
			paintCheck()
		end))
	end

	if #links > 0 then
		local row = Create.new("Frame", {
			Name = "Links",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 5,
			Parent = body,
		})
		Create.List(row, Enum.FillDirection.Horizontal, 8)
		local count = #links
		for index, link in ipairs(links) do
			local button = PushButton.new(
				theme,
				row,
				link.Name,
				"Default",
				index,
				UDim2.new(1 / count, -8 * (count - 1) / count, 1, 0)
			)
			self._maid:Give(button.Activated:Connect(function()
				self:_openLink(link)
			end))
		end
	end

	local dragStart
	Drag.bind(header, {
		OnStart = function()
			dragStart = self._offset
		end,
		OnDelta = function(delta)
			if not dragStart then
				return
			end
			local vp = self:_viewport()
			local offset = dragStart + delta / self._uiScale
			self._offset = Vector2.new(
				math.clamp(offset.X, -(vp.X / 2 - 80), vp.X / 2 - 80),
				math.clamp(offset.Y, -(vp.Y / 2 - 40), vp.Y / 2 - 40)
			)
			main.Position = UDim2.new(0.5, self._offset.X, 0.5, self._offset.Y)
		end,
	}, self._maid)

	self._maid:Give(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_layout()
	end))
	self:_layout()

	local env = Env()
	local preset = cfg.Key
	if not preset and type(env.script_key) == "string" and env.script_key ~= "" then
		preset = env.script_key
	end
	local fromFile = false
	if not preset and self._saveEnabled then
		preset = readSaved(self._file)
		fromFile = preset ~= nil
	end
	if preset then
		box.Text = preset
		self._silent, self._presetFromFile = true, fromFile
		self:_submit(preset)
	else
		self:_show()
	end
	return self
end

function KeyGate:_viewport()
	return self._gui.AbsoluteSize / self._uiScale
end

function KeyGate:_layout()
	local abs = self._gui.AbsoluteSize
	if abs.X <= 0 or abs.Y <= 0 then
		return
	end
	local scale = math.clamp(math.min(abs.Y / (self._height + 60), abs.X / 420), 0.6, 1)
	self._uiScale = scale
	self._rootScale.Scale = scale
	self._root.Size = UDim2.fromOffset(abs.X / scale, abs.Y / scale)
	self._main.Size = UDim2.fromOffset(math.min(WIDTH, abs.X / scale - 24), self._height)
end

function KeyGate:_show()
	if self._shown or self._destroyed then
		return
	end
	self._shown = true
	self._gui.Enabled = true
	Tween.play(self._pop, { Scale = 1 }, self.Theme:Get().Animation.Normal)
end

function KeyGate:_paintStatus()
	local c = self.Theme:Get().Colors
	self._status.Text = self._statusText
	self._status.TextColor3 = c[STATUS_COLORS[self._statusKind]] or c.TextDim
end

function KeyGate:SetStatus(text, kind)
	self._statusText = tostring(text or "")
	self._statusKind = STATUS_COLORS[kind] and kind or "Info"
	if not self._destroyed then
		self:_paintStatus()
	end
end

function KeyGate:_openLink(link)
	local copied = false
	if setclipboard then
		copied = pcall(setclipboard, link.Url)
	end
	if copied then
		self:SetStatus(link.Name .. " link copied to your clipboard.", "Info")
	else
		self:SetStatus(link.Url, "Info")
	end
end

function KeyGate:_submit(rawKey)
	if self._busy or self._locked or self._destroyed or self._done then
		return
	end
	local key = trim(rawKey)
	if key == "" then
		self:SetStatus("Enter your key first.", "Error")
		return
	end
	self._busy = true
	self._verifyApi.SetDisabled(true)
	self:SetStatus("Checking key...", "Info")

	local finished = false
	task.delay(self._timeout, function()
		if not finished and not self._destroyed then
			finished = true
			self:_failed("The key service did not respond. Try again.")
		end
	end)
	task.spawn(function()
		local ok, valid, message, data = pcall(self._validate, key)
		if finished or self._destroyed then
			return
		end
		finished = true
		if not ok then
			self:_failed("Key check failed. Try again.")
		elseif valid then
			self:_succeed(key, data, message)
		else
			self:_failed(message or "That key is not valid.")
		end
	end)
end

function KeyGate:_failed(message)
	self._busy = false
	if self._silent then
		self._silent = false
		if self._presetFromFile then
			writeSaved(self._file, "")
			message = "Your saved key is no longer valid."
		end
		self:_show()
	end
	self._fails = self._fails + 1
	self:SetStatus(message, "Error")
	if self._fails >= self._maxAttempts then
		self:_lock()
	else
		self._verifyApi.SetDisabled(false)
	end
end

function KeyGate:_lock()
	self._locked = true
	task.spawn(function()
		for remaining = self._cooldown, 1, -1 do
			if self._destroyed then
				return
			end
			self:SetStatus("Too many attempts. Try again in " .. remaining .. "s.", "Error")
			task.wait(1)
		end
		if self._destroyed then
			return
		end
		self._locked, self._fails = false, 0
		self._verifyApi.SetDisabled(false)
		self:SetStatus("You can try again.", "Info")
	end)
end

function KeyGate:_succeed(key, data, message)
	self._busy = false
	self._done = true
	self._silent = false
	if self._saveEnabled then
		writeSaved(self._file, self._remember and key or "")
	end
	self:SetStatus(message or "Key accepted.", "Success")
	self._result = { true, key, data }
	local callback = self._cfg.OnSuccess
	if callback then
		task.spawn(function()
			local ok, err = pcall(callback, key, data)
			if not ok then
				warn("[UI] OnSuccess errored: " .. tostring(err))
			end
		end)
	end
	self:_resolve()
	task.delay(self._shown and 0.7 or 0, function()
		self:Destroy()
	end)
end

function KeyGate:_resolve()
	local waiters = self._waiters
	self._waiters = {}
	for _, thread in ipairs(waiters) do
		task.spawn(thread, table.unpack(self._result, 1, 3))
	end
end

function KeyGate:Wait()
	if self._result then
		return table.unpack(self._result, 1, 3)
	end
	self._waiters[#self._waiters + 1] = coroutine.running()
	return coroutine.yield()
end

function KeyGate:_onDestroy(fn)
	self._destroyCallbacks[#self._destroyCallbacks + 1] = fn
end

function KeyGate:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if not self._done then
		self._done = true
		self._result = { false }
		local callback = self._cfg.OnClose
		if callback then
			pcall(callback)
		end
		self:_resolve()
	end
	for _, fn in ipairs(self._destroyCallbacks) do
		pcall(fn)
	end
	self._maid:Destroy()
end

return KeyGate
