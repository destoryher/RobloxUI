return function()
	local ok, value = pcall(function()
		return getgenv()
	end)
	if ok and type(value) == "table" then
		return value
	end
	return _G
end
