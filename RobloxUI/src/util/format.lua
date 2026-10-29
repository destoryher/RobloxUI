-- Number formatting and parsing for live stats.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local PARSE = {
	k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18,
	sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33,
}

local function trim(text)
	text = string.gsub(text, "%.?0+$", "")
	return text
end

local function fixed(n, decimals)
	if decimals <= 0 then
		return string.format("%d", n >= 0 and math.floor(n + 0.5) or -math.floor(-n + 0.5))
	end
	return trim(string.format("%." .. decimals .. "f", n))
end

-- 1234 -> "1.23K", 15300000 -> "15.3M"; three significant digits.
function Format.compact(n)
	if n ~= n then
		return "0"
	end
	if n == math.huge or n == -math.huge then
		return n > 0 and "inf" or "-inf"
	end
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	if n < 1000 then
		if n == math.floor(n) then
			return sign .. string.format("%d", n)
		end
		return sign .. fixed(n, n < 10 and 2 or 1)
	end
	local tier = math.floor(math.log10(n) / 3)
	if tier >= #SUFFIXES then
		return sign .. trim(string.format("%.2e", n))
	end
	local scaled = n / 10 ^ (tier * 3)
	if scaled >= 999.5 and tier + 1 < #SUFFIXES then
		tier = tier + 1
		scaled = scaled / 1000
	end
	local decimals = scaled < 10 and 2 or (scaled < 100 and 1 or 0)
	return sign .. fixed(scaled, decimals) .. SUFFIXES[tier + 1]
end

-- 1234567 -> "1,234,567"
function Format.commas(n, decimals)
	local text = fixed(n, decimals or 0)
	local sign, int, frac = string.match(text, "^(-?)(%d+)(.*)$")
	if not int then
		return text
	end
	int = string.reverse((string.gsub(string.reverse(int), "(%d%d%d)", "%1,")))
	int = string.gsub(int, "^,", "")
	return sign .. int .. frac
end

-- 3725 -> "1h 02m", 125 -> "2m 05s", 9 -> "9s"
function Format.duration(seconds)
	seconds = math.max(math.floor(seconds or 0), 0)
	local d = math.floor(seconds / 86400)
	local h = math.floor(seconds % 86400 / 3600)
	local m = math.floor(seconds % 3600 / 60)
	local s = seconds % 60
	if d > 0 then
		return string.format("%dd %02dh", d, h)
	end
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	if m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

-- 3725 -> "1:02:05"
function Format.clock(seconds)
	seconds = math.max(math.floor(seconds or 0), 0)
	local h = math.floor(seconds / 3600)
	local m = math.floor(seconds % 3600 / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- Reads numbers the way games display them: 1234, "1,234", "$1.5M", "12.3K Coins", "2.1e6".
-- Returns nil when there is no number in the text.
function Format.parse(value)
	if type(value) == "number" then
		return value
	end
	if type(value) == "boolean" then
		return value and 1 or 0
	end
	if type(value) ~= "string" then
		return nil
	end
	local text = string.gsub(value, ",", "")
	local number, rest = string.match(text, "(%-?%d+%.?%d*[eE][%+%-]?%d+)(.*)")
	if number then
		return tonumber(number)
	end
	number, rest = string.match(text, "(%-?%d*%.?%d+)%s*(%a*)")
	if not number then
		return nil
	end
	local n = tonumber(number)
	if not n then
		return nil
	end
	local suffix = string.lower(rest or "")
	local mult = PARSE[string.sub(suffix, 1, 2)] or PARSE[string.sub(suffix, 1, 1)]
	if mult and (#suffix <= 2 or PARSE[string.sub(suffix, 1, 2)]) then
		n = n * mult
	end
	return n
end

-- Formats a value for a stat. `style` is Compact (default), Number, Money, Time, Clock, Percent, Text,
-- or a function(value) -> string. Prefix and suffix wrap the result.
function Format.value(value, style, decimals, prefix, suffix)
	local text
	if type(style) == "function" then
		local ok, result = pcall(style, value)
		text = ok and tostring(result) or tostring(value)
	elseif type(value) ~= "number" then
		text = value == nil and "--" or tostring(value)
	elseif style == "Number" then
		text = Format.commas(value, decimals or 0)
	elseif style == "Money" then
		text = (value < 0 and "-$" or "$") .. Format.compact(math.abs(value))
	elseif style == "Time" then
		text = Format.duration(value)
	elseif style == "Clock" then
		text = Format.clock(value)
	elseif style == "Percent" then
		text = fixed(value, decimals or 1) .. "%"
	elseif style == "Text" then
		text = tostring(value)
	else
		text = Format.compact(value)
	end
	return (prefix or "") .. text .. (suffix or "")
end

return Format
