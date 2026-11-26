-- =====================================================================
--  LAFL LIB – core (server)
--  Exports used by the modules of other resources + minigame sessions + logs.
-- =====================================================================

local LIB = GetCurrentResourceName()

if LIB ~= 'lafl_lib' then
    print(('^1[lafl_lib] The resource folder must be named "lafl_lib" (is "%s"). LAFL scripts will not find it.^7'):format(LIB))
end

-- ---------------------------------------------------------------------
--  Config + custom functions
-- ---------------------------------------------------------------------

exports('GetConfig', function()
    local copy = {}
    for k, v in pairs(LibConfig) do
        if k ~= 'Logs' then copy[k] = v end   -- webhooks stay inside lafl_lib
    end
    return copy
end)

exports('CallCustom', function(name, ...)
    local fn = CustomBridge and CustomBridge[name]
    if type(fn) ~= 'function' then return false end
    return true, fn(...)
end)

exports('HasCustom', function(name)
    return CustomBridge ~= nil and type(CustomBridge[name]) == 'function'
end)

exports('GetVersion', function() return LAFL.Version end)

-- ---------------------------------------------------------------------
--  Logs (CustomBridge.Log + Discord webhook)
-- ---------------------------------------------------------------------

local queue, sending = {}, false

local function sendQueue()
    if sending then return end
    sending = true
    CreateThread(function()
        while #queue > 0 do
            local item = table.remove(queue, 1)
            PerformHttpRequest(item.url, function(status)
                if status ~= 204 and status ~= 200 then
                    LAFL.Debug('Discord webhook answered', status)
                end
            end, 'POST', json.encode(item.body), { ['Content-Type'] = 'application/json' })
            Wait(1200)   -- Discord rate limit
        end
        sending = false
    end)
end

local function fieldValue(v)
    if type(v) == 'table' then return json.encode(v) end
    return tostring(v)
end

function LAFL_WriteLog(resource, src, action, data)
    src = tonumber(src) or 0
    local info = {
        resource   = resource,
        source     = src,
        name       = src > 0 and LAFL.Player.GetName(src) or 'Server',
        identifier = src > 0 and LAFL.Player.GetIdentifier(src) or nil,
        time       = os.time(),
    }

    if CustomBridge and CustomBridge.Log then
        local ok, err = pcall(CustomBridge.Log, resource, src, action, data, info)
        if not ok then print(('^1[lafl_lib] CustomBridge.Log error: %s^7'):format(tostring(err))) end
    end

    local cfg = LibConfig.Logs or {}
    if not cfg.discord then return end
    if action == 'flagged' and cfg.flagged == false then return end
    local url = (cfg.webhooks and cfg.webhooks[resource]) or cfg.webhook
    if not url or url == '' then return end

    local fields = {
        { name = 'Player', value = ('%s (%d)'):format(info.name, src), inline = true },
        { name = 'ID', value = tostring(info.identifier or '-'), inline = true },
    }
    local keys = {}
    for k in pairs(data or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        if #fields < 25 then fields[#fields + 1] = { name = tostring(k), value = fieldValue(data[k]):sub(1, 1000), inline = true } end
    end

    queue[#queue + 1] = {
        url = url,
        body = {
            username = cfg.username or 'LAFL Logs',
            embeds = { {
                title = ('%s · %s'):format(resource, action),
                color = action == 'flagged' and 15686476 or (cfg.color or 15251530),
                fields = fields,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            } },
        },
    }
    sendQueue()
end

exports('Log', function(resource, src, action, data)
    LAFL_WriteLog(resource, src, action, data)
end)

-- ---------------------------------------------------------------------
--  Minigames started by the server (token check)
-- ---------------------------------------------------------------------

local VALID = {
    lockpick = true, skillcheck = true, hack = true, thermite = true,
    safe = true, drill = true, wires = true, keypad = true,
}
local DEFAULT_TIME = 120   -- seconds, if a game has no time limit

local sessions = {}   -- token -> session
local active = {}     -- src -> token

local function newToken()
    local t = {}
    for i = 1, 32 do t[i] = ('%x'):format(math.random(0, 15)) end
    return table.concat(t)
end

local function finish(token, result)
    local s = sessions[token]
    if not s then return end
    sessions[token] = nil
    if active[s.src] == token then active[s.src] = nil end
    s.p:resolve(result)
end

exports('MinigameActive', function(src) return active[tonumber(src)] ~= nil end)

exports('MinigameAwait', function(src, game, opts)
    src = tonumber(src)
    opts = opts or {}
    if not src or not GetPlayerName(src) then return false end
    if not VALID[game] then
        print(('^1[lafl_lib] Unknown minigame: %s^7'):format(tostring(game)))
        return false
    end
    if active[src] then return false end

    local token = newToken()
    local rounds = math.max(1, tonumber(opts.rounds) or 1)
    local perRound = (LibConfig.Minigames.minTime or {})[game] or 500
    local s = {
        src = src,
        game = game,
        started = GetGameTimer(),
        minMs = perRound * rounds,
        p = promise.new(),
    }
    sessions[token] = s
    active[src] = token

    TriggerClientEvent('lafl_lib:minigame:start', src, token, game, opts)

    local limit = (tonumber(opts.time) or DEFAULT_TIME) + (LibConfig.Minigames.timeoutBuffer or 15)
    SetTimeout(math.floor(limit * 1000), function()
        if sessions[token] then
            LAFL.Debug('Minigame timeout', game, src)
            finish(token, false)
        end
    end)

    return Citizen.Await(s.p)
end)

RegisterNetEvent('lafl_lib:minigame:result', function(token, success)
    local src = source
    local s = type(token) == 'string' and sessions[token]
    if not s then
        if success == true then LAFL.Security.Flag(src, 'minigame result without valid token') end
        return
    end
    if s.src ~= src then
        LAFL.Security.Flag(src, 'minigame result for another player', { game = s.game })
        return
    end
    local elapsed = GetGameTimer() - s.started
    if success == true and elapsed < s.minMs then
        LAFL.Security.Flag(src, 'minigame solved impossibly fast', { game = s.game, ms = elapsed, min = s.minMs })
        finish(token, false)
        return
    end
    finish(token, success == true)
end)

AddEventHandler('playerDropped', function()
    local token = active[source]
    if token then finish(token, false) end
end)

-- ---------------------------------------------------------------------
--  Start message
-- ---------------------------------------------------------------------

CreateThread(function()
    math.randomseed(os.time() + GetGameTimer())
    print(('^2[lafl_lib] v%s started^7 – framework: %s, inventory: %s, target: %s, notify: %s, dispatch: %s'):format(
        LAFL.Version, LibConfig.Framework, LibConfig.Inventory, LibConfig.Target, LibConfig.Notify, LibConfig.Dispatch))
end)
