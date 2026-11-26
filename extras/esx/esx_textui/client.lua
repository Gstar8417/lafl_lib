-- =====================================================================
--  esx_textui replacement (lafl_lib/extras)
--  Same API as the original esx_textui:
--    exports['esx_textui']:TextUI(message, type)   exports['esx_textui']:HideUI()
--    events 'ESX:TextUI' / 'ESX:HideUI' (from the server only)
--  ESX.TextUI / ESX.HideUI use it automatically.
--  "Press [E] to open" / "~INPUT_CONTEXT~ Open" -> key E in the key box, text "Open".
-- =====================================================================

local LIB = 'lafl_lib'
local showing = false
local nativeText = nil

local function useLib()
    if GetResourceState(LIB) ~= 'started' then return false end
    local ok, modes = pcall(function() return exports[LIB]:GetUIModes() end)
    return ok and type(modes) == 'table' and modes.textui ~= 'esx'
end

---@param message string
---@param typ? string 'info' | 'success' | 'error' (only used by the original design)
local function TextUI(message, typ)
    showing = true
    message = message ~= nil and tostring(message) or 'ESX-TextUI'

    if useLib() then
        nativeText = nil
        exports[LIB]:ShowTextUIAuto(message)
        return
    end

    -- fallback: GTA help box while shown
    nativeText = message
    CreateThread(function()
        local text = message
        while showing and nativeText == text do
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(text)
            EndTextCommandDisplayHelp(0, false, false, -1)
            Wait(0)
        end
    end)
end

local function HideUI()
    if not showing then return end
    showing = false
    nativeText = nil
    if GetResourceState(LIB) == 'started' then
        -- never hide the "[E] ..." of lafl_lib's own target mode
        local ok, owner = pcall(function() return exports[LIB]:TextUIOwner() end)
        if ok and owner == 'script' then exports[LIB]:HideTextUI() end
    end
end

exports('TextUI', TextUI)
exports('HideUI', HideUI)

-- like ESX.SecureNetEvent: only accepted from the server
RegisterNetEvent('ESX:TextUI', function(...)
    if source == '' then return end
    TextUI(...)
end)
RegisterNetEvent('ESX:HideUI', function()
    if source == '' then return end
    HideUI()
end)
