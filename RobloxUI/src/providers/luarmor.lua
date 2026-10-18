local Validate = require("util/validate")
local Env = require("util/env")

local Luarmor = {}

local SDK_URL = "https://sdkapi-public.luarmor.net/library.lua"

local MESSAGES = {
	KEY_HWID_LOCKED = "This key is locked to another device. Reset it from your key panel.",
	KEY_INCORRECT = "That key is incorrect.",
	KEY_INVALID = "That key is not valid.",
	KEY_EXPIRED = "This key has expired.",
	KEY_BANNED = "This key has been blacklisted.",
	SCRIPT_ID_INCORRECT = "The script id is incorrect.",
	SCRIPT_ID_INVALID = "The script id is not valid.",
	INVALID_EXECUTOR = "This executor is not supported.",
	SECURITY_ERROR = "Security check failed. Try again.",
	TIME_ERROR = "Your system clock is out of sync.",
	UNKNOWN_ERROR = "Unknown error. Try again.",
}

function Luarmor.new(opts)
	Validate.check("Providers.Luarmor", opts, {
		ScriptId = "string!",
		SdkUrl = "string",
		Messages = "table",
	})

	local provider = {}
	local sdk

	local function load()
		if not sdk then
			local library = loadstring(game:HttpGet(opts.SdkUrl or SDK_URL))()
			library.script_id = opts.ScriptId
			sdk = library
		end
		return sdk
	end

	function provider.Validate(key)
		local ok, result = pcall(function()
			return load().check_key(key)
		end)
		if not ok or type(result) ~= "table" then
			return false, "Could not reach the key service. Check your connection."
		end
		if result.code == "KEY_VALID" then
			return true, result.message or "Key accepted.", result.data
		end
		local custom = opts.Messages and opts.Messages[result.code]
		return false, custom or MESSAGES[result.code] or result.message or "That key was not accepted.", result
	end

	function provider.LoadScript(key)
		if type(key) == "string" then
			Env().script_key = key
		end
		return load().load_script()
	end

	return provider
end

return Luarmor
