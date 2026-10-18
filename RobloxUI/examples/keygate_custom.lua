local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/v0.7.1/dist/ui.lua"))()

local gate = Library:CreateKeyGate({
	Title = "My Script",
	Validate = function(key)
		if key == "example-key" then
			return true, "Key accepted.", { expires = "never" }
		end
		return false, "That key is not valid."
	end,
})

local ok, key, data = gate:Wait()
if ok then
	print("unlocked", key)
end
