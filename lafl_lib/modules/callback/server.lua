-- =====================================================================
--  LAFL.Callback (server)
--
--  LAFL.Callback.Register('getView', function(src, stationId) return {...} end)
--  LAFL.Callback.Register('wash', fn, { cooldown = 500 })   -- min. ms between calls per player
-- =====================================================================

local Callback = {}
local handlers = {}
local lastCall = {}

local EV_REQ = LAFL.Event('lafl:cb:req')
local EV_RES = LAFL.Event('lafl:cb:res')

function Callback.Register(name, fn, opts)
    handlers[name] = { fn = fn, cooldown = opts and opts.cooldown or 0 }
end

function Callback.Remove(name)
    handlers[name] = nil
end

RegisterNetEvent(EV_REQ, function(name, id, ...)
    local src = source
    if type(id) ~= 'number' or type(name) ~= 'string' then return end

    local h = handlers[name]
    if not h then
        LAFL.Debug('Unknown callback', name, 'from', src)
        TriggerClientEvent(EV_RES, src, id)
        return
    end

    if h.cooldown > 0 then
        local key = src .. ':' .. name
        local now = GetGameTimer()
        if lastCall[key] and now - lastCall[key] < h.cooldown then
            TriggerClientEvent(EV_RES, src, id)
            return
        end
        lastCall[key] = now
    end

    local ret = table.pack(pcall(h.fn, src, ...))
    if not ret[1] then
        print(('^1[%s] Callback "%s" error: %s^7'):format(LAFL.resource, name, tostring(ret[2])))
        TriggerClientEvent(EV_RES, src, id)
        return
    end
    TriggerClientEvent(EV_RES, src, id, table.unpack(ret, 2, ret.n))
end)

AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for key in pairs(lastCall) do
        if key:sub(1, #prefix) == prefix then lastCall[key] = nil end
    end
end)

return Callback
