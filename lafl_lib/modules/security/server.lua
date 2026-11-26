-- =====================================================================
--  LAFL.Security (server) – distance, locks, cooldowns, rate limit
-- =====================================================================

local Security = {}

local locks, cooldowns, rates = {}, {}, {}

--- Server position of a player. OneSync does not update the position of a
--- ped that sits in a vehicle, so the vehicle position is used then.
function Security.Coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then return GetEntityCoords(veh) end
    return GetEntityCoords(ped)
end

--- Is the player within maxDist of coords? (default LibConfig.MaxActionDistance)
--- Correct for players in vehicles (since 1.0.5).
function Security.InRange(src, coords, maxDist)
    local pc = Security.Coords(src)
    if not pc or not coords then return false end
    return #(vec3(pc.x, pc.y, pc.z) - vec3(coords.x, coords.y, coords.z)) <= (maxDist or LAFL.Config.MaxActionDistance or 6.0)
end

-- ---------------------------------------------------------------------
--  Locks: one action per player at a time (double clicks, spam)
-- ---------------------------------------------------------------------

--- true if the lock was free and is now taken (auto-release after 30 s)
function Security.Lock(src, key)
    key = src .. ':' .. (key or 'default')
    local now = GetGameTimer()
    if locks[key] and locks[key] > now then return false end
    locks[key] = now + 30000
    return true
end

function Security.Unlock(src, key)
    locks[src .. ':' .. (key or 'default')] = nil
end

function Security.IsLocked(src, key)
    local t = locks[src .. ':' .. (key or 'default')]
    return t ~= nil and t > GetGameTimer()
end

--- Runs fn while locked. Returns false, 'busy' if the player is already busy.
function Security.WithLock(src, key, fn, ...)
    if not Security.Lock(src, key) then return false, 'busy' end
    local ret = table.pack(pcall(fn, ...))
    Security.Unlock(src, key)
    if not ret[1] then error(ret[2], 0) end
    return table.unpack(ret, 2, ret.n)
end

-- ---------------------------------------------------------------------
--  Cooldowns (any key, e.g. identifier .. '|' .. locationId)
-- ---------------------------------------------------------------------

function Security.SetCooldown(key, seconds)
    cooldowns[key] = os.time() + seconds
end

--- Remaining seconds (0 = no cooldown)
function Security.GetCooldown(key)
    local t = cooldowns[key]
    if not t then return 0 end
    local left = t - os.time()
    if left <= 0 then cooldowns[key] = nil return 0 end
    return left
end

function Security.ClearCooldown(key)
    cooldowns[key] = nil
end

-- ---------------------------------------------------------------------
--  Rate limit: true if allowed, false if called again within ms
-- ---------------------------------------------------------------------

function Security.RateLimit(src, key, ms)
    key = src .. ':' .. key
    local now = GetGameTimer()
    if rates[key] and now - rates[key] < ms then return false end
    rates[key] = now
    return true
end

-- ---------------------------------------------------------------------
--  Suspicious action: console + LAFL.Log (action 'flagged')
-- ---------------------------------------------------------------------

function Security.Flag(src, reason, data)
    print(('^1[%s] Suspicious action by %s (%s): %s^7'):format(LAFL.resource, GetPlayerName(src) or '?', tostring(src), tostring(reason)))
    data = data or {}
    data.reason = reason
    LAFL.Log(src, 'flagged', data)
end

-- ---------------------------------------------------------------------
--  Cleanup
-- ---------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    local prefix = source .. ':'
    for key in pairs(locks) do if key:sub(1, #prefix) == prefix then locks[key] = nil end end
    for key in pairs(rates) do if key:sub(1, #prefix) == prefix then rates[key] = nil end end
end)

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for key, t in pairs(cooldowns) do if t <= now then cooldowns[key] = nil end end
    end
end)

return Security
