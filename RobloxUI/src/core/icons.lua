local Create = require("util/create")
local Glyphs = require("util/glyphs")

local Icons = {}
local registry = {}

local DEFAULTS = {
	home = "\u{1F3E0}", main = "\u{1F3E0}", farm = "\u{1F33E}", pets = "\u{1F43E}", pet = "\u{1F43E}",
	shop = "\u{1F6D2}", egg = "\u{1F95A}", eggs = "\u{1F95A}", settings = "\u{2699}\u{FE0F}", config = "\u{2699}\u{FE0F}",
	misc = "\u{1F527}", tools = "\u{1F6E0}\u{FE0F}", visuals = "\u{1F441}\u{FE0F}", esp = "\u{1F441}\u{FE0F}", eye = "\u{1F441}\u{FE0F}",
	webhook = "\u{1F514}", notifications = "\u{1F514}", bell = "\u{1F514}", trophy = "\u{1F3C6}", leaderboard = "\u{1F3C6}",
	star = "\u{2B50}", event = "\u{1F389}", events = "\u{1F389}", fire = "\u{1F525}", gift = "\u{1F381}",
	user = "\u{1F464}", player = "\u{1F464}", combat = "\u{2694}\u{FE0F}", sword = "\u{2694}\u{FE0F}", target = "\u{1F3AF}",
	filter = "\u{1F50E}", filters = "\u{1F50E}", search = "\u{1F50E}", map = "\u{1F5FA}\u{FE0F}", teleport = "\u{1F5FA}\u{FE0F}",
	money = "\u{1F4B0}", cash = "\u{1F4B0}", gem = "\u{1F48E}", rocket = "\u{1F680}", speed = "\u{1F680}",
	lock = "\u{1F512}", info = "\u{2139}\u{FE0F}", list = "\u{1F4CB}", progression = "\u{1F4CB}", code = "\u{1F4BB}",
	heart = "\u{2764}\u{FE0F}", bolt = "\u{26A1}", lightning = "\u{26A1}", palette = "\u{1F3A8}", theme = "\u{1F3A8}",
	appearance = "\u{1F3A8}", keyboard = "\u{2328}\u{FE0F}", keybinds = "\u{2328}\u{FE0F}", save = "\u{1F4BE}", auto = "\u{1F916}",
	robot = "\u{1F916}", flag = "\u{1F3C1}", race = "\u{1F3C1}", clock = "\u{23F1}\u{FE0F}", time = "\u{23F1}\u{FE0F}",
	bug = "\u{1F41B}", chat = "\u{1F4AC}", inventory = "\u{1F392}", backpack = "\u{1F392}", ghost = "\u{1F47B}",
}

function Icons.Register(name, value)
	if type(name) ~= "string" then
		error("[UI] icon name must be a string", 0)
	end
	registry[name:lower()] = value
end

function Icons.Guess(name)
	local key = string.lower(tostring(name))
	if registry[key] ~= nil or DEFAULTS[key] ~= nil then
		return key
	end
	return nil
end

local remoteCache = {}
local remotePending = {}

local function hash(text)
	local value = 5381
	for index = 1, #text do
		value = (value * 33 + string.byte(text, index)) % 4294967296
	end
	return value
end

local function fetchRemote(url)
	if remoteCache[url] ~= nil then
		return remoteCache[url] or nil
	end
	local ok, result = pcall(function()
		local extension = string.match(url, "%.(%a+)[%?#]?[^/]*$")
		extension = (extension == "jpg" or extension == "jpeg" or extension == "webp") and extension or "png"
		local name = "RobloxUI_icon_" .. hash(url) .. "." .. extension
		if not (isfile and isfile(name)) then
			writefile(name, game:HttpGet(url))
		end
		return getcustomasset(name)
	end)
	remoteCache[url] = ok and result or false
	return ok and result or nil
end

local function whenRemote(url, callback)
	local cached = remoteCache[url]
	if cached then
		callback(cached)
		return
	end
	if cached == false then
		return
	end
	local waiting = remotePending[url]
	if waiting then
		waiting[#waiting + 1] = callback
		return
	end
	remotePending[url] = { callback }
	task.spawn(function()
		local asset = fetchRemote(url)
		local callbacks = remotePending[url]
		remotePending[url] = nil
		if asset then
			for _, fn in ipairs(callbacks) do
				pcall(fn, asset)
			end
		end
	end)
end

local function describeValue(value, depth)
	if depth > 2 then
		return nil
	end
	if type(value) == "number" then
		return "image", "rbxassetid://" .. value
	end
	if type(value) ~= "string" or value == "" then
		return nil
	end
	if value:find("^rbxassetid://") or value:find("^rbxasset://") or value:find("^rbxthumb://") then
		return "image", value
	end
	if value:find("^mark:") then
		return "mark", string.sub(value, 6)
	end
	if value:find("^https?://") then
		local cached = remoteCache[value]
		if cached then
			return "image", cached
		end
		if cached == false then
			return nil
		end
		return nil, nil, value
	end
	local key = value:lower()
	if registry[key] ~= nil then
		return describeValue(registry[key], depth + 1)
	end
	if DEFAULTS[key] then
		return "glyph", DEFAULTS[key]
	end
	if value:find("[\128-\255]") then
		return "glyph", value
	end
	return nil
end

function Icons.Describe(icon)
	return describeValue(icon, 0)
end

local function populate(obj, kind, value, fallback, size, opts)
	local frame = obj.Frame
	for _, child in ipairs(frame:GetChildren()) do
		child:Destroy()
	end
	obj.Kind = kind or "letter"
	obj.IsImage = kind == "image"
	local inner

	if kind == "image" then
		local image = Create.new("ImageLabel", { Size = UDim2.fromScale(1, 1), Image = value, Parent = frame })
		if opts.Corner then
			Create.Corner(image, opts.Corner)
		end
		function inner(color)
			if opts.Tint ~= false then
				image.ImageColor3 = color
			end
		end
	elseif kind == "mark" then
		local style = string.upper(string.sub(value, 1, 1)) .. string.lower(string.sub(value, 2))
		Glyphs.mark(frame, style, size, opts.Theme)
		function inner() end
	elseif kind == "glyph" then
		local label = Create.new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = value,
			Font = Enum.Font.Gotham,
			TextSize = math.floor(size * 0.78),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Parent = frame,
		})
		function inner(_color, active)
			label.TextTransparency = (active == false) and 0.45 or 0
		end
	else
		local glyph = Create.new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(string.sub(fallback or "?", 1, 1)),
			Font = Enum.Font.GothamBold,
			TextSize = math.floor(size * 0.62),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = frame,
		})
		function inner(color)
			glyph.TextColor3 = color
		end
	end

	obj._inner = inner
	if obj._color ~= nil then
		inner(obj._color, obj._active)
	end
end

function Icons.Make(parent, icon, fallback, size, opts)
	opts = opts or {}
	local kind, value, pending = describeValue(icon, 0)
	local frame = Create.new("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	local obj = { Frame = frame }
	function obj.Paint(self, color, active)
		self._color, self._active = color, active
		self._inner(color, active)
	end
	populate(obj, kind, value, fallback, size, opts)

	if pending then
		whenRemote(pending, function(asset)
			if frame.Parent then
				populate(obj, "image", asset, fallback, size, opts)
				if opts.OnChange then
					pcall(opts.OnChange, obj)
				end
			end
		end)
	end
	return obj
end

return Icons
