-- =====================================================================
--  LAFL.Locale – texts with English fallback
--
--  local L = LAFL.Locale(Config.Locales)       -- language from Config.Locale
--  L('started', amount)                          -- string.format with arguments
--  L.title                                       -- plain access
--  L.All()                                       -- merged table (e.g. for the NUI)
-- =====================================================================

local Locale = {}

local function create(locales, lang)
    locales = locales or {}
    lang = lang or LAFL.Lang()
    local primary = locales[lang] or {}
    local fallback = locales.en or {}

    local function get(key)
        local v = primary[key]
        if v == nil then v = fallback[key] end
        return v
    end

    local L = {}

    function L.All()
        local out = {}
        for k, v in pairs(fallback) do out[k] = v end
        for k, v in pairs(primary) do out[k] = v end
        return out
    end

    function L.Lang() return lang end
    function L.Has(key) return get(key) ~= nil end

    return setmetatable(L, {
        __index = function(_, key) return get(key) end,
        __call = function(_, key, ...)
            local text = get(key)
            if text == nil then return tostring(key) end
            if select('#', ...) > 0 then
                local ok, res = pcall(string.format, text, ...)
                return ok and res or text
            end
            return text
        end,
    })
end

return setmetatable(Locale, {
    __call = function(_, locales, lang) return create(locales, lang) end,
})
