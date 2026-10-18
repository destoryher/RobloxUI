local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/v0.7.1/dist/ui.lua"))()

local luarmor = Library.Providers.Luarmor({ ScriptId = "YOUR_LUARMOR_SCRIPT_ID" })

Library:CreateKeyGate({
	Title = "My Script",
	Subtitle = "Enter your key to continue",
	Provider = luarmor,
	Links = {
		{ Name = "Get key", Url = "https://example.com/getkey" },
		{ Name = "Discord", Url = "https://discord.gg/example" },
	},
	OnSuccess = function(key)
		luarmor.LoadScript(key)
	end,
})
