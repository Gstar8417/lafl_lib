-- =====================================================================
--  CUSTOM SYSTEMS (client)
--  Only used when 'custom' is selected in lafl_lib/config.lua.
--  Applies to ALL LAFL scripts at once.
-- =====================================================================

CustomBridge = {}

--- Notification (LibConfig.Notify = 'custom')
--- @param msg string
--- @param ntype string 'inform' | 'success' | 'error' | 'warning'
--- @param opts table { title, duration, icon }
function CustomBridge.Notify(msg, ntype, opts)
    -- Example: exports['my_notify']:Show(opts.title, msg, ntype, opts.duration)
    print(('[%s] %s'):format(ntype, msg))
end

--- Progress bar (LibConfig.Progress = 'custom'). MUST return true (finished) or false (cancelled).
--- @param opts table { duration, label, anim, prop, canCancel, disable }
function CustomBridge.Progress(opts)
    -- Example: return exports['my_progress']:Start(opts.label, opts.duration)
    Wait(opts.duration or 0)
    return true
end

--- Text UI (LibConfig.TextUI = 'custom')
function CustomBridge.ShowTextUI(text, opts)
    -- Example: exports['my_textui']:Show(('[%s] %s'):format(opts.key or 'E', text))
end

function CustomBridge.HideTextUI()
    -- Example: exports['my_textui']:Hide()
end

--- Dispatch alert (LibConfig.Dispatch = 'custom'). Runs on the client of the player who caused it.
--- @param coords vector3
--- @param alert table { code, title, message, sprite, color, scale, length, radius, jobs, codeName, icon, priority }
--- @param street string street name at coords
function CustomBridge.Dispatch(coords, alert, street)
    -- Add the call of your dispatch script here.
    LAFL.Debug('Dispatch alert at', coords, alert.title, street)
end

-- ---------------------------------------------------------------------
--  Standalone (LibConfig.Framework = 'standalone') – optional
-- ---------------------------------------------------------------------

-- function CustomBridge.GetPlayerData() return {} end
-- function CustomBridge.GetJob() return 'unemployed', 0, true end    -- name, grade, onDuty
-- function CustomBridge.GetGang() return nil, 0 end

-- Inventory = 'custom': amount of an item on the client (for target checks)
-- function CustomBridge.ClientItemCount(item) return 0 end
