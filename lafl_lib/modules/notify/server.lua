-- =====================================================================
--  LAFL.Notify (server)
--  LAFL.Notify(src, 'Text', 'success', { title = '...' })    -- src = -1 for everyone
-- =====================================================================

local Notify = {}
local defaults = {}

function Notify.SetDefaults(opts)
    defaults = opts or {}
end

function Notify.Send(src, msg, ntype, opts)
    local o = {}
    for k, v in pairs(defaults) do o[k] = v end
    for k, v in pairs(opts or {}) do o[k] = v end
    TriggerClientEvent('lafl_lib:notify', src, msg, ntype, o)
end

return setmetatable(Notify, {
    __call = function(_, src, msg, ntype, opts) Notify.Send(src, msg, ntype, opts) end,
})
