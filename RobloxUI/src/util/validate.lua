local Validate = {}

function Validate.check(where, cfg, schema)
	if type(cfg) ~= "table" then
		error(("[UI] %s: expected a config table, got %s"):format(where, typeof(cfg)), 0)
	end
	for key, spec in pairs(schema) do
		local required = spec:sub(-1) == "!"
		local types = required and spec:sub(1, -2) or spec
		local value = cfg[key]
		if value == nil then
			if required then
				error(("[UI] %s: missing required field '%s' (%s)"):format(where, key, types), 0)
			end
		else
			local matched = false
			for expected in types:gmatch("[^|]+") do
				if typeof(value) == expected then
					matched = true
					break
				end
			end
			if not matched then
				error(("[UI] %s: field '%s' must be %s, got %s"):format(where, key, types, typeof(value)), 0)
			end
		end
	end
	return cfg
end

return Validate
