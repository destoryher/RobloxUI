local Maid = {}
Maid.__index = Maid

local function release(item)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "table" then
		if type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

function Maid.new()
	return setmetatable({ _items = {}, _dead = false }, Maid)
end

function Maid:Give(item)
	if self._dead then
		pcall(release, item)
		return item
	end
	self._items[#self._items + 1] = item
	return item
end

function Maid:Clean()
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(release, items[i])
		if not ok then
			warn("[UI] cleanup error: " .. tostring(err))
		end
	end
end

function Maid:Destroy()
	self._dead = true
	self:Clean()
end

return Maid
