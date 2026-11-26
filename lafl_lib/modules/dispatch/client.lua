-- =====================================================================
--  LAFL.Dispatch (client) – system from LibConfig.Dispatch
--
--  LAFL.Dispatch.Send(coords, {
--      code = '10-90', title = 'Geldwäsche', message = 'Verdächtige Aktivität',
--      sprite = 500, color = 1, scale = 1.0, length = 3, radius = 0,   -- blip (minutes)
--      jobs = { 'leo' }, codeName = 'laundering', icon = 'fas fa-money-bill-wave', priority = 2,
--      chance = 100,                                                    -- % (optional)
--  })
-- =====================================================================

local Dispatch = {}

function Dispatch.Send(coords, alert)
    exports[LAFL.name]:Dispatch(coords, alert or {})
end

return Dispatch
