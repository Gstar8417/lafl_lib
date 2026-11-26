-- =====================================================================
--  LAFL.Callback (client)
--
--  local view = LAFL.Callback.Await('getView', stationId)     -- waits (timeout -> nil)
--  LAFL.Callback.Trigger('getView', function(view) end, stationId)
-- =====================================================================

local Callback = {}
local counter, pending = 0, {}

local EV_REQ = LAFL.Event('lafl:cb:req')
local EV_RES = LAFL.Event('lafl:cb:res')

function Callback.Await(name, ...)
    counter = counter + 1
    local id = counter
    local p = promise.new()
    pending[id] = p

    TriggerServerEvent(EV_REQ, name, id, ...)

    SetTimeout(LAFL.Config.CallbackTimeout or 10000, function()
        if pending[id] then
            pending[id] = nil
            LAFL.Debug('Callback timeout', name)
            p:resolve({ n = 0 })
        end
    end)

    local ret = Citizen.Await(p)
    return table.unpack(ret, 1, ret.n)
end

function Callback.Trigger(name, cb, ...)
    local args = table.pack(...)
    CreateThread(function()
        cb(Callback.Await(name, table.unpack(args, 1, args.n)))
    end)
end

RegisterNetEvent(EV_RES, function(id, ...)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    p:resolve(table.pack(...))
end)

return Callback
