--!strict
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Format.Number(value: number): string
	if value ~= value or value == math.huge then
		return "0"
	end
	local magnitude = 1
	local scaled = value
	while math.abs(scaled) >= 1000 and magnitude < #SUFFIXES do
		scaled /= 1000
		magnitude += 1
	end
	if magnitude == 1 then
		return tostring(math.floor(scaled + 0.5))
	end
	local text = string.format("%.2f%s", scaled, SUFFIXES[magnitude])
	text = string.gsub(text, "%.00", "")
	return text
end

function Format.Percent(value: number): string
	if value >= 10 then
		return string.format("%.1f%%", value)
	elseif value >= 0.1 then
		return string.format("%.2f%%", value)
	end
	return string.format("%.3f%%", value)
end

function Format.Clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Format.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm", seconds // 60)
	end
	return string.format("%ds", seconds)
end

return Format
