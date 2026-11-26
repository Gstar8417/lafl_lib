-- =====================================================================
--  LAFL.Notify (client)
--  LAFL.Notify('Text', 'success')                      -- inform | success | error | warning
--  LAFL.Notify('Text', 'error', { title = 'Bank', duration = 7000, icon = '💰' })
--  LAFL.Notify.SetDefaults({ title = 'Geldwäsche', icon = '🧺' })   -- once per script
-- =====================================================================

local Notify = {}
local defaults = {}

function Notify.SetDefaults(opts)
    defaults = opts or {}
end

function Notify.Send(msg, ntype, opts)
    local o = {}
    for k, v in pairs(defaults) do o[k] = v end
    for k, v in pairs(opts or {}) do o[k] = v end
    exports[LAFL.name]:Notify(msg, ntype, o)
end

return setmetatable(Notify, {
    __call = function(_, msg, ntype, opts) Notify.Send(msg, ntype, opts) end,
})
