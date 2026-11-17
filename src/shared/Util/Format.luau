--!strict
-- Number / time formatting for the UI.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn", "Sx" }

-- 1234 -> "1.23K", 15300000 -> "15.3M"
function Format.Short(n: number): string
	n = math.floor(n)
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		return (negative and "-" or "") .. tostring(n)
	end
	local index = 1
	local value = n
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text
	if value >= 100 then
		text = string.format("%d", math.floor(value))
	elseif value >= 10 then
		text = string.format("%.1f", math.floor(value * 10) / 10)
	else
		text = string.format("%.2f", math.floor(value * 100) / 100)
	end
	if text:find(".", 1, true) then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return (negative and "-" or "") .. text .. SUFFIXES[index]
end

-- 1234567 -> "1,234,567"
function Format.Commas(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^(-?),", "%1"))
end

-- 75 -> "1m 15s", 4 -> "4s"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds < 60 then
		return seconds .. "s"
	end
	local minutes = seconds // 60
	local rest = seconds % 60
	if minutes < 60 then
		return string.format("%dm %02ds", minutes, rest)
	end
	return string.format("%dh %02dm", minutes // 60, minutes % 60)
end

-- 0.25 -> "+25%"
function Format.Percent(fraction: number): string
	local pct = fraction * 100
	if pct >= 100 then
		return string.format("+%d%%", math.floor(pct + 0.5))
	end
	local text = string.format("%.1f", pct):gsub("%.0$", "")
	return "+" .. text .. "%"
end

function Format.Multiplier(m: number): string
	local text = string.format("%.2f", m):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. text
end

return Format
