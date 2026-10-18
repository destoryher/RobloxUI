local Window = require("core/window")
local ThemeManager = require("theme/manager")
local Icons = require("core/icons")
local KeyGate = require("core/keygate")
local Luarmor = require("providers/luarmor")
local Env = require("util/env")

local VERSION = "@VERSION@"
local BUILD = "@BUILD@"

local Library = {
	Version = VERSION,
	Build = BUILD,
}

Library.Providers = { Luarmor = Luarmor.new }

local function registry()
	local root = Env()
	root.__RobloxUILib = root.__RobloxUILib or {}
	return root.__RobloxUILib
end

function Library:CreateWindow(cfg)
	local reg = registry()
	local key = type(cfg) == "table" and tostring(cfg.Id or cfg.Title) or nil
	if key and reg[key] then
		pcall(function()
			reg[key]:Destroy()
		end)
		reg[key] = nil
	end
	local window = Window.new(cfg)
	if key then
		reg[key] = window
		window:_onDestroy(function()
			if reg[key] == window then
				reg[key] = nil
			end
		end)
	end
	return window
end

function Library:CreateKeyGate(cfg)
	local reg = registry()
	local key = type(cfg) == "table" and ("gate:" .. tostring(cfg.Title)) or nil
	if key and reg[key] then
		pcall(function()
			reg[key]:Destroy()
		end)
		reg[key] = nil
	end
	local gate = KeyGate.new(cfg)
	if key then
		reg[key] = gate
		gate:_onDestroy(function()
			if reg[key] == gate then
				reg[key] = nil
			end
		end)
	end
	return gate
end

function Library:CheckVersion(expected)
	local wanted = tonumber(string.match(tostring(expected), "^(%d+)"))
	local mine = tonumber(string.match(VERSION, "^(%d+)"))
	return wanted ~= nil and mine ~= nil and wanted == mine
end

function Library:RegisterTheme(name, overrides)
	ThemeManager.Register(name, overrides)
end

function Library:RegisterIcons(map)
	if type(map) ~= "table" then
		error("[UI] RegisterIcons expects a table of name = assetId", 0)
	end
	for name, id in pairs(map) do
		Icons.Register(name, id)
	end
end

function Library:DestroyAll()
	local reg = registry()
	for key, window in pairs(reg) do
		pcall(function()
			window:Destroy()
		end)
		reg[key] = nil
	end
end

return Library
