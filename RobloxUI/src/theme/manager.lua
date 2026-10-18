local Themes = require("theme/themes")
local Create = require("util/create")

local Manager = {}
Manager.__index = Manager

local function clone(source)
	local out = {}
	for key, value in pairs(source) do
		out[key] = type(value) == "table" and clone(value) or value
	end
	return out
end

local function merge(base, override)
	local out = clone(base)
	for key, value in pairs(override) do
		if type(value) == "table" and type(out[key]) == "table" then
			out[key] = merge(out[key], value)
		else
			out[key] = value
		end
	end
	return out
end

local registry = { Dark = clone(Themes.Dark) }
for name, override in pairs(Themes) do
	if name ~= "Dark" then
		registry[name] = merge(registry.Dark, override)
	end
end

function Manager.Register(name, override)
	if type(name) ~= "string" or type(override) ~= "table" then
		error("[UI] RegisterTheme expects (name: string, overrides: table)", 0)
	end
	registry[name] = merge(registry.Dark, override)
end

function Manager.Names()
	local names = {}
	for name in pairs(registry) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function Manager.new(spec)
	local self = setmetatable({ _watchers = {} }, Manager)
	self:Set(spec or "Mono", true)
	return self
end

function Manager:Get()
	return self._theme
end

function Manager:Name()
	return self._name
end

function Manager:Set(spec, silent)
	local theme, name
	if type(spec) == "string" then
		theme = registry[spec]
		if not theme then
			error(("[UI] unknown theme '%s' (available: %s)"):format(spec, table.concat(Manager.Names(), ", ")), 0)
		end
		name = spec
	elseif type(spec) == "table" then
		theme = merge(registry.Dark, spec)
		name = "Custom"
	else
		error("[UI] theme must be a theme name or a table of overrides", 0)
	end
	self._theme, self._name = theme, name
	self._base = clone(theme.Transparency)
	if not silent then
		self:_notify()
	end
end

function Manager:_notify()
	local list = {}
	for _, fn in pairs(self._watchers) do
		list[#list + 1] = fn
	end
	for _, fn in ipairs(list) do
		local ok, err = pcall(fn, self._theme)
		if not ok then
			warn("[UI] theme watcher error: " .. tostring(err))
		end
	end
end

function Manager:Patch(override)
	self._theme = merge(self._theme, override)
	self:_notify()
end

function Manager:Watch(fn)
	local handle = {}
	self._watchers[handle] = fn
	function handle.Disconnect()
		self._watchers[handle] = nil
	end
	handle.Destroy = handle.Disconnect
	fn(self._theme)
	return handle
end

function Manager:Bind(inst, map)
	local handle = self:Watch(function(theme)
		for prop, source in pairs(map) do
			local value
			if type(source) == "function" then
				value = source(theme)
			else
				value = theme.Colors[source]
				if value == nil then
					warn("[UI] unknown theme token '" .. tostring(source) .. "'")
				end
			end
			if value ~= nil then
				inst[prop] = value
			end
		end
	end)
	inst.Destroying:Connect(function()
		handle.Disconnect()
	end)
	return handle
end

function Manager:Corner(parent, key)
	local corner = Create.new("UICorner", { Parent = parent })
	self:Bind(corner, {
		CornerRadius = function(theme)
			return UDim.new(0, theme.Radius[key])
		end,
	})
	return corner
end

function Manager:Stroke(parent, token, thickness)
	local stroke = Create.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = thickness or 1,
		Parent = parent,
	})
	self:Bind(stroke, { Color = token })
	return stroke
end

function Manager:Text(inst, color, font, size)
	return self:Bind(inst, {
		TextColor3 = color,
		Font = function(theme)
			return theme.Font[font or "Medium"]
		end,
		TextSize = function(theme)
			return theme.TextSize[size or "Body"]
		end,
	})
end

return Manager
