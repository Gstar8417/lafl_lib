-- =====================================================================
--  esx_notify replacement (lafl_lib/extras)
--  Same API as the original esx_notify:
--    exports['esx_notify']:Notify(type, length, message, title, position)
--    TriggerClientEvent('ESX:Notify', src, type, length, message, title, position)
--  ESX.ShowNotification / xPlayer.showNotification use it automatically.
-- =====================================================================

local LIB = 'lafl_lib'

--- Can lafl_lib show it? (not if lafl_lib itself is set to 'esx' – that would loop back here)
local function useLib()
    if GetResourceState(LIB) ~= 'started' then return false end
    local ok, modes = pcall(function() return exports[LIB]:GetUIModes() end)
    return ok and type(modes) == 'table' and modes.notify ~= 'esx'
end

local function nativeNotify(message, title)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(title and ('~h~%s~h~~n~%s'):format(title, message) or message)
    EndTextCommandThefeedPostTicker(false, true)
end

---@param notifyType string 'info' | 'success' | 'error' | 'warning'
---@param length number ms
---@param message any
---@param title? string
---@param position? string (ignored – the position is set in lafl_lib/config.lua)
local function Notify(notifyType, length, message, title, position)
    if type(notifyType) ~= 'string' then notifyType = 'info' end
    length = tonumber(length)
    if not length or length ~= length or length <= 0 or length == math.huge then length = 3000 end
    message = message ~= nil and tostring(message) or ''
    if type(title) ~= 'string' or title == '' then title = nil end

    if useLib() then
        exports[LIB]:Notify(message, notifyType, { title = title, duration = length })
    else
        nativeNotify(message, title)
    end
end

exports('Notify', Notify)
RegisterNetEvent('ESX:Notify', Notify)
