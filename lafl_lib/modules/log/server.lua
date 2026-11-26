-- =====================================================================
--  LAFL.Log (server)
--  LAFL.Log(src, 'claim', { laundry = 'vespucci', clean = 5000 })
--  -> CustomBridge.Log in lafl_lib/custom/server.lua + optional Discord webhook
--     (webhook URLs stay in lafl_lib/config_server.lua)
-- =====================================================================

local Log = {}

function Log.Send(src, action, data)
    if LAFL.resource == LAFL.name then
        LAFL_WriteLog(LAFL.resource, src, action, data or {})
    else
        exports[LAFL.name]:Log(LAFL.resource, src, action, data or {})
    end
end

return setmetatable(Log, {
    __call = function(_, src, action, data) Log.Send(src, action, data) end,
})
