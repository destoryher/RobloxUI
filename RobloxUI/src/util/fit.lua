-- Text measuring and wrapping. Instead of cutting text off with "...",
-- labels wrap onto extra lines and their row grows to fit them.
local TextService = require("util/services").TextService

local Fit = {}

local HUGE = 100000
local cache = {}
local cacheSize = 0

local function measure(text, size, font, width)
	local key = text .. "\0" .. tostring(size) .. "\0" .. tostring(font) .. "\0" .. tostring(width)
	local hit = cache[key]
	if hit then
		return hit
	end
	if not TextService then
		return nil
	end
	local ok, result = pcall(TextService.GetTextSize, TextService, text, size, font, Vector2.new(width, HUGE))
	if not ok then
		return nil
	end
	if cacheSize >= 512 then
		cache, cacheSize = {}, 0
	end
	cache[key] = result
	cacheSize = cacheSize + 1
	return result
end

-- Width of `text` on one line, in unscaled pixels.
function Fit.width(text, size, font)
	local bounds = measure(text, size, font, HUGE)
	return bounds and math.ceil(bounds.X) or #text * size * 0.55
end

-- Height of `text` when wrapped to `width` unscaled pixels.
function Fit.height(text, size, font, width)
	local bounds = measure(text, size, font, math.max(math.floor(width), 1))
	return bounds and math.ceil(bounds.Y) or size
end

-- Keeps `container` tall enough for `label` to wrap its text onto several lines.
-- A single line keeps the container at `base` height; every extra line adds its height on top.
-- opts:
--   label, container, base, maid
--   scale()      returns the current unscaled-to-absolute factor, or nil while the window animates
--   reserve      pixels kept free next to the label (number, or function(width) -> number)
--   padX         horizontal padding inside the label
--   sizeLabel    set the label width to the container width minus `reserve`
--   watch        extra TextLabels whose text affects `reserve`
function Fit.bind(opts)
	local label, container = opts.label, opts.container
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None

	local lastKey
	local queued = false

	local function refit()
		queued = false
		if not label.Parent or not container.Parent then
			return
		end
		local scale = opts.scale()
		if not scale then
			return
		end
		local width = math.floor(container.AbsoluteSize.X / scale + 0.5)
		if width <= 0 then
			return
		end
		local reserve = opts.reserve or 0
		if type(reserve) == "function" then
			reserve = reserve(width)
		end
		local avail = math.max(width - reserve - (opts.padX or 0), 1)
		local text, size, font = label.Text, label.TextSize, label.Font
		local key = table.concat({ text, tostring(size), tostring(font), tostring(avail), tostring(reserve) }, "\0")
		if key == lastKey then
			return
		end
		lastKey = key
		if opts.sizeLabel then
			label.Size = UDim2.new(1, -reserve, label.Size.Y.Scale, label.Size.Y.Offset)
		end
		local line = Fit.height("Ag", size, font, HUGE)
		local height = Fit.height(text ~= "" and text or "Ag", size, font, avail)
		local extra = math.max(height - line, 0)
		local current = container.Size
		local target = opts.base + extra
		if current.Y.Offset ~= target or current.Y.Scale ~= 0 then
			container.Size = UDim2.new(current.X.Scale, current.X.Offset, 0, target)
		end
	end

	local function queue()
		if queued then
			return
		end
		queued = true
		task.defer(refit)
	end

	local maid = opts.maid
	maid:Give(container:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue))
	for _, prop in ipairs({ "Text", "TextSize", "Font" }) do
		maid:Give(label:GetPropertyChangedSignal(prop):Connect(queue))
	end
	for _, other in ipairs(opts.watch or {}) do
		maid:Give(other:GetPropertyChangedSignal("Text"):Connect(queue))
		maid:Give(other:GetPropertyChangedSignal("TextSize"):Connect(queue))
	end
	queue()

	return {
		Refit = function()
			lastKey = nil
			queue()
		end,
	}
end

return Fit
