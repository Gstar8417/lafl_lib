-- =====================================================================
--  LAFL.Dispatch (server)
--  LAFL.Dispatch.Send(src, coords, alert)
--  Sent through the client of `src` (ps-dispatch / cd_dispatch need it for street names).
-- =====================================================================

local Dispatch = {}

function Dispatch.Send(src, coords, alert)
    alert = alert or {}
    if alert.chance and math.random(100) > alert.chance then return false end
    alert.chance = nil
    TriggerClientEvent('lafl_lib:dispatch', src, coords, alert)
    return true
end

return Dispatch
