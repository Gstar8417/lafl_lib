-- =====================================================================
--  LAFL.Format – numbers, money and time (de / en)
-- =====================================================================

local Format = {}

--- 12500 -> '12.500' (de) or '12,500' (en)
function Format.Number(n, lang)
    lang = lang or LAFL.Lang()
    local num = math.floor(tonumber(n) or 0)
    local neg = num < 0
    local s = tostring(math.abs(num))
    local sep = lang == 'de' and '.' or ','
    s = s:reverse():gsub('(%d%d%d)', '%1' .. sep):reverse()
    if s:sub(1, 1) == sep then s = s:sub(2) end
    return (neg and '-' or '') .. s
end

--- 12500 -> '12.500 $' (de) or '$12,500' (en)
function Format.Money(amount, lang)
    lang = lang or LAFL.Lang()
    local cur = (type(Config) == 'table' and Config.Currency) or LAFL.Config.Currency or '$'
    local n = Format.Number(amount, lang)
    if lang == 'de' then return n .. ' ' .. cur end
    if n:sub(1, 1) == '-' then return '-' .. cur .. n:sub(2) end
    return cur .. n
end

--- 754 -> '12:34', 3700 -> '1:01:40'
function Format.Time(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local h, m, s = sec // 3600, sec % 3600 // 60, sec % 60
    if h > 0 then return ('%d:%02d:%02d'):format(h, m, s) end
    return ('%d:%02d'):format(m, s)
end

--- 3720 -> '1 Std. 2 Min.' (de) / '1h 2m' (en)
function Format.Duration(sec, lang)
    lang = lang or LAFL.Lang()
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local d, h, m, s = sec // 86400, sec % 86400 // 3600, sec % 3600 // 60, sec % 60
    local u = lang == 'de' and { ' T.', ' Std.', ' Min.', ' Sek.' } or { 'd', 'h', 'm', 's' }
    local parts = {}
    if d > 0 then parts[#parts + 1] = d .. u[1] end
    if h > 0 then parts[#parts + 1] = h .. u[2] end
    if m > 0 and d == 0 then parts[#parts + 1] = m .. u[3] end
    if s > 0 and d == 0 and h == 0 then parts[#parts + 1] = s .. u[4] end
    if #parts == 0 then return '0' .. u[4] end
    return table.concat(parts, ' ')
end

--- vec4 text for coordinate commands
function Format.Coords(c, heading)
    if heading then return ('vec4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, heading) end
    return ('vec3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z)
end

return Format
