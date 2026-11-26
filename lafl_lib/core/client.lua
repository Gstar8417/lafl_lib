-- =====================================================================
--  LAFL LIB – core (client)
--  Central notify / progress / text UI / dispatch / minigames for all
--  LAFL scripts (one NUI, same look everywhere).
-- =====================================================================

local L = LAFL.Locale(LibConfig.Locales, LibConfig.Locale)
local nuiReady = false
local nuiQueue = {}

local function send(msg)
    if nuiReady then SendNUIMessage(msg) else nuiQueue[#nuiQueue + 1] = msg end
end

RegisterNUICallback('ready', function(_, cb)
    cb(1)
    SendNUIMessage({
        action = 'init',
        data = {
            ui = LibConfig.UI,
            lang = LibConfig.Locale,
            locale = L.All(),
            notify = LibConfig.NotifySettings,
            progress = LibConfig.ProgressSettings,
            textui = LibConfig.TextUISettings,
            sounds = LibConfig.Minigames.sounds,
            debug = LibConfig.Debug == true,
        },
    })
    nuiReady = true
    for _, msg in ipairs(nuiQueue) do SendNUIMessage(msg) end
    nuiQueue = {}
end)

exports('GetConfig', function() return LibConfig end)

exports('CallCustom', function(name, ...)
    local fn = CustomBridge and CustomBridge[name]
    if type(fn) ~= 'function' then return false end
    return true, fn(...)
end)

exports('HasCustom', function(name)
    return CustomBridge ~= nil and type(CustomBridge[name]) == 'function'
end)

exports('GetVersion', function() return LAFL.Version end)

exports('CopyText', function(text)
    send({ action = 'copy', text = tostring(text) })
end)

-- ---------------------------------------------------------------------
--  Notify
-- ---------------------------------------------------------------------

local typeMap = { info = 'inform', primary = 'inform', inform = 'inform', success = 'success', error = 'error', warning = 'warning', warn = 'warning' }

local function notify(msg, ntype, opts)
    ntype = typeMap[ntype or 'inform'] or 'inform'
    opts = opts or {}
    msg = tostring(msg or '')
    local mode = LibConfig.Notify

    if mode == 'lafl' then
        send({ action = 'notify', data = {
            message = msg, type = ntype, title = opts.title, icon = opts.icon,
            duration = opts.duration or LibConfig.NotifySettings.duration,
        } })
    elseif mode == 'ox_lib' then
        exports.ox_lib:notify({
            title = opts.title, description = msg, type = ntype == 'warning' and 'warning' or ntype,
            duration = opts.duration, position = LibConfig.NotifySettings.position,
        })
    elseif mode == 'qb' then
        local map = { inform = 'primary', success = 'success', error = 'error', warning = 'error' }
        LAFL.Core.QB().Functions.Notify(msg, map[ntype], opts.duration)
    elseif mode == 'esx' then
        local map = { inform = 'info', success = 'success', error = 'error', warning = 'error' }
        LAFL.Core.ESX().ShowNotification(msg, map[ntype], opts.duration)
    elseif mode == 'custom' and CustomBridge.Notify then
        CustomBridge.Notify(msg, ntype, opts)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(opts.title and ('~h~%s~h~~n~%s'):format(opts.title, msg) or msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

exports('Notify', notify)
RegisterNetEvent('lafl_lib:notify', notify)

-- ---------------------------------------------------------------------
--  Progress
-- ---------------------------------------------------------------------

local progress = nil

local DISABLE = {
    move   = { 21, 22, 30, 31, 32, 33, 34, 35, 36, 44 },
    car    = { 63, 64, 71, 72, 75 },
    combat = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 257, 263, 264 },
    mouse  = { 1, 2, 106 },
}

local function disableControls(disable)
    for group, on in pairs(disable) do
        if on and DISABLE[group] then
            for _, c in ipairs(DISABLE[group]) do DisableControlAction(0, c, true) end
        end
    end
end

local function laflProgress(opts)
    local ped = PlayerPedId()
    local duration = math.max(100, tonumber(opts.duration) or 3000)
    local canCancel = opts.canCancel ~= false
    local disable = opts.disable or { move = true, car = true, combat = true }
    local cancelKey = LibConfig.ProgressSettings.cancelKey or 73

    progress = { cancelled = false }
    LAFL.Anim.Play(opts.anim)
    local prop = opts.prop and LAFL.Anim.AttachProp(opts.prop)

    send({ action = 'progress', data = {
        label = opts.label or L.working, duration = duration,
        cancel = canCancel and L.cancel or nil,
    } })

    local endTime = GetGameTimer() + duration
    local ok = true
    local nextAnimCheck = 0

    while GetGameTimer() < endTime do
        Wait(0)
        disableControls(disable)
        if progress.cancelled or IsEntityDead(ped) or (canCancel and IsControlJustPressed(0, cancelKey)) then
            ok = false
            break
        end
        if opts.anim and opts.anim.dict and GetGameTimer() > nextAnimCheck then
            nextAnimCheck = GetGameTimer() + 1000
            if not LAFL.Anim.IsPlaying(opts.anim, ped) then LAFL.Anim.Play(opts.anim, ped) end
        end
    end

    send({ action = 'progressEnd', ok = ok })
    if opts.anim then LAFL.Anim.Stop(ped) end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    progress = nil
    return ok
end

local function nativeProgress(opts)
    local ped = PlayerPedId()
    local duration = math.max(100, tonumber(opts.duration) or 3000)
    progress = { cancelled = false }
    LAFL.Anim.Play(opts.anim)
    local endTime = GetGameTimer() + duration
    local ok = true
    while GetGameTimer() < endTime do
        Wait(0)
        disableControls(opts.disable or { move = true, car = true, combat = true })
        local pct = math.floor((1.0 - (endTime - GetGameTimer()) / duration) * 100)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(('%s ~b~%d%%~s~~n~~INPUT_VEH_DUCK~ %s'):format(opts.label or L.working, pct, L.cancel))
        EndTextCommandDisplayHelp(0, false, false, -1)
        if progress.cancelled or IsEntityDead(ped) or (opts.canCancel ~= false and IsControlJustPressed(0, 73)) then
            ok = false
            break
        end
    end
    if opts.anim then LAFL.Anim.Stop(ped) end
    progress = nil
    return ok
end

local function runProgress(opts)
    if progress then return false end
    opts = opts or {}
    local mode = LibConfig.Progress

    if mode == 'lafl' then return laflProgress(opts) end
    if mode == 'native' then return nativeProgress(opts) end

    progress = { cancelled = false, external = true }
    local ok = false
    local disable = opts.disable or { move = true, car = true, combat = true }

    if mode == 'ox_lib' then
        local anim
        if opts.anim and opts.anim.scenario then anim = { scenario = opts.anim.scenario }
        elseif opts.anim then anim = { dict = opts.anim.dict, clip = opts.anim.clip, flag = opts.anim.flag or 1 } end
        ok = exports.ox_lib:progressBar({
            duration = opts.duration, label = opts.label or L.working, useWhileDead = false,
            canCancel = opts.canCancel ~= false, disable = disable, anim = anim,
            prop = opts.prop and { model = opts.prop.model, bone = opts.prop.bone, pos = opts.prop.pos, rot = opts.prop.rot } or nil,
        }) == true

    elseif mode == 'qb' then
        local p = promise.new()
        local anim = {}
        if opts.anim and opts.anim.scenario then anim = { task = opts.anim.scenario }
        elseif opts.anim then anim = { animDict = opts.anim.dict, anim = opts.anim.clip, flags = opts.anim.flag or 1 } end
        LAFL.Core.QB().Functions.Progressbar('lafl_progress', opts.label or L.working, opts.duration, false, opts.canCancel ~= false, {
            disableMovement = disable.move == true, disableCarMovement = disable.car == true,
            disableMouse = disable.mouse == true, disableCombat = disable.combat == true,
        }, anim, {}, {}, function() p:resolve(true) end, function() p:resolve(false) end)
        ok = Citizen.Await(p)
        LAFL.Anim.Stop()

    elseif mode == 'esx' then
        local p = promise.new()
        local animation
        if opts.anim and opts.anim.scenario then animation = { type = 'Scenario', Scenario = opts.anim.scenario }
        elseif opts.anim then animation = { type = 'anim', dict = opts.anim.dict, lib = opts.anim.clip } end
        LAFL.Core.ESX().Progressbar(opts.label or L.working, opts.duration, {
            FreezePlayer = disable.move == true, animation = animation,
            onFinish = function() p:resolve(true) end,
            onCancel = function() p:resolve(false) end,
        })
        ok = Citizen.Await(p)
        LAFL.Anim.Stop()

    elseif mode == 'custom' and CustomBridge.Progress then
        ok = CustomBridge.Progress(opts) == true
    else
        progress = nil
        return nativeProgress(opts)
    end

    progress = nil
    return ok
end

exports('Progress', runProgress)
exports('ProgressActive', function() return progress ~= nil end)
exports('CancelProgress', function()
    if not progress then return end
    progress.cancelled = true
    if progress.external and LibConfig.Progress == 'ox_lib' then pcall(function() exports.ox_lib:cancelProgress() end) end
end)

-- ---------------------------------------------------------------------
--  Text UI
-- ---------------------------------------------------------------------

local textOpen, nativeText = false, nil
local textOwner = nil     -- 'target' = shown by the text UI target, else 'script'

exports('ShowTextUI', function(text, opts)
    opts = opts or {}
    local mode = LibConfig.TextUI
    textOpen = true
    textOwner = opts.__target and 'target' or 'script'

    if mode == 'lafl' then
        local key = opts.key
        if key == nil then key = 'E' end
        send({ action = 'textui', data = { text = text, key = key or false, icon = opts.icon } })
    elseif mode == 'ox_lib' then
        exports.ox_lib:showTextUI(('[%s] %s'):format(opts.key or 'E', text), { position = 'left-center', icon = opts.oxIcon })
    elseif mode == 'qb' then
        exports['qb-core']:DrawText(('[%s] %s'):format(opts.key or 'E', text), 'left')
    elseif mode == 'esx' then
        LAFL.Core.ESX().TextUI(('[%s] %s'):format(opts.key or 'E', text), 'info')
    elseif mode == 'custom' and CustomBridge.ShowTextUI then
        CustomBridge.ShowTextUI(text, opts)
    else
        nativeText = text
        CreateThread(function()
            while textOpen and nativeText == text do
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(text)
                EndTextCommandDisplayHelp(0, false, false, -1)
                Wait(0)
            end
        end)
    end
end)

exports('HideTextUI', function()
    if not textOpen then return end
    textOpen = false
    textOwner = nil
    nativeText = nil
    local mode = LibConfig.TextUI
    if mode == 'lafl' then send({ action = 'textuiHide' })
    elseif mode == 'ox_lib' then exports.ox_lib:hideTextUI()
    elseif mode == 'qb' then exports['qb-core']:HideText()
    elseif mode == 'esx' then LAFL.Core.ESX().HideUI()
    elseif mode == 'custom' and CustomBridge.HideTextUI then CustomBridge.HideTextUI() end
end)

exports('IsTextUIOpen', function() return textOpen end)

-- ---------------------------------------------------------------------
--  Text from other scripts: "Press [E] to open", "[E] - Open", "~INPUT_CONTEXT~ Open"
--  -> key "E" goes into the key box, the rest becomes the text
-- ---------------------------------------------------------------------

local INPUT_KEYS = {
    INPUT_CONTEXT = 'E', INPUT_PICKUP = 'E', INPUT_TALK = 'E', INPUT_DETONATE = 'G', INPUT_VEH_HORN = 'E',
    INPUT_ENTER = 'F', INPUT_COVER = 'Q', INPUT_RELOAD = 'R', INPUT_JUMP = 'Space', INPUT_SPRINT = 'Shift',
    INPUT_FRONTEND_ACCEPT = 'Enter', INPUT_CELLPHONE_SELECT = 'Enter', INPUT_FRONTEND_RRIGHT = 'Backspace',
    INPUT_VEH_EXIT = 'F', INPUT_VEH_HEADLIGHT = 'H', INPUT_REPLAY_START_STOP_RECORDING_SECONDARY = 'F2',
}

-- key names that are accepted without brackets ("E - Open", "BACKSPACE - Exit")
local KEY_NAMES = {}
for _, k in ipairs({ 'ALT', 'LALT', 'RALT', 'CTRL', 'LCTRL', 'RCTRL', 'SHIFT', 'LSHIFT', 'RSHIFT', 'TAB', 'ENTER', 'SPACE',
    'BACKSPACE', 'DEL', 'DELETE', 'ESC', 'INS', 'HOME', 'END', 'PAGEUP', 'PAGEDOWN', 'CAPS', 'WHEELUP', 'WHEELDOWN',
    'LMB', 'RMB', 'MMB', 'UP', 'DOWN', 'LEFT', 'RIGHT', 'ARROW UP', 'ARROW DOWN', 'ARROW LEFT', 'ARROW RIGHT' }) do KEY_NAMES[k] = true end
for i = 1, 12 do KEY_NAMES['F' .. i] = true end

local function isKeyName(k) return #k == 1 or KEY_NAMES[k] == true end

--- "E - Store Vehicle" / "[E] - Exit" / "[E] Open" -> "Store Vehicle", "E"
local function splitKey(line)
    local k, rest = line:match('^%s*%[%s*([%w]+)%s*%]%s*[%-:]?%s*(.*)$')
    if k then return k, rest end
    k, rest = line:match('^%s*([%u%d]+ ?[%u]*)%s+%-%s+(.*)$')       -- E - Open / ARROW LEFT - Turn left
    if k and isKeyName(k) then return k, rest end
    return nil, line
end

--- remaining keys inside the text are shown as small key chips: "| [G] - Manage" -> " · **G** Manage"
local function inlineKeys(text)
    text = text:gsub('%s*|%s*', ' \u{2003}')
    text = text:gsub('%[%s*([%w]+)%s*%]%s*[%-:]?%s*', '**%1** ')
    return text
end

local function parseKeyText(message)
    local text = tostring(message or ''):gsub('\r', '')
    local key

    -- several lines with keys (key help of a placement mode ...): no key box, every line "KEY Label"
    local lines = {}
    for line in (text .. '\n'):gmatch('(.-)\n') do
        line = line:gsub('^%s+', ''):gsub('%s+$', '')
        if line ~= '' then lines[#lines + 1] = line end
    end
    if #lines > 1 then
        local keyed = 0
        for i, line in ipairs(lines) do
            local k, rest = splitKey(line)
            if k then keyed = keyed + 1; lines[i] = ('**%s** %s'):format(k, inlineKeys(rest)) else lines[i] = inlineKeys(line) end
        end
        if keyed > 0 then return table.concat(lines, '\n'), nil end
        return text, nil
    end
    text = lines[1] or ''

    -- GTA input token
    text = text:gsub('~(INPUT_[%w_]+)~', function(name)
        if not key then key = INPUT_KEYS[name] or 'E' end
        return ''
    end, 1)
    if not key then
        -- "[E] ..." anywhere (first one), or "E - ..." at the start
        local k, rest = splitKey(text)
        if k then
            key, text = k, rest
        else
            local found
            text = text:gsub('%[%s*([%w]+)%s*%]', function(f) if not found then found = f return '' end end, 1)
            key = found
        end
    end
    if key then
        -- tidy up what is left: "Press  to open" -> "Open", "- Open" -> "Open"
        text = text:gsub('^%s*[%-:|]%s*', '')
        for _, w in ipairs({ 'Press ', 'press ', 'Drücke ', 'drücke ', 'Druecke ', 'Drück ', 'Hold ', 'Halte ' }) do
            if text:sub(1, #w) == w then text = text:sub(#w + 1) break end
        end
        text = text:gsub('^%s*', ''):gsub('^to%s+', ''):gsub('^um%s+', ''):gsub('^zum%s+', 'Zum ')
        text = text:gsub('%s+', ' '):gsub('^%s*[%-:|]%s*', ''):gsub('%s+$', '')
        text = text:gsub('^%l', string.upper)
    end
    return inlineKeys(text), key
end

--- Text UI for text written by other scripts (used by the ESX / QB replacements)
exports('ShowTextUIAuto', function(message, opts)
    opts = opts or {}
    local text, key = parseKeyText(message)
    if opts.key ~= nil then key = opts.key end
    exports[GetCurrentResourceName()]:ShowTextUI(text, { key = key or false, icon = opts.icon })
end)

-- GTA help box replacement (ESX.ShowHelpNotification, called every frame by most scripts):
-- shows the LAFL text UI and hides it again shortly after the calls stop.
local helpUntil, helpText, helpThread = 0, nil, false
exports('HelpText', function(message, duration)
    local msg = tostring(message or '')
    helpUntil = GetGameTimer() + ((tonumber(duration) or 0) > 0 and tonumber(duration) or 250)
    if msg ~= helpText or not textOpen then
        helpText = msg
        local text, key = parseKeyText(msg)
        exports[GetCurrentResourceName()]:ShowTextUI(text, { key = key or false })
    end
    if helpThread then return end
    helpThread = true
    CreateThread(function()
        while GetGameTimer() < helpUntil do Wait(100) end
        if helpText and textOpen and textOwner == 'script' then exports[GetCurrentResourceName()]:HideTextUI() end
        helpText, helpThread = nil, false
    end)
end)

-- for the replacements: their own fallback when lafl_lib would send the call back to them
exports('GetUIModes', function()
    return { notify = LibConfig.Notify, progress = LibConfig.Progress, textui = LibConfig.TextUI }
end)
exports('TextUIOwner', function() return textOpen and textOwner or nil end)

-- ---------------------------------------------------------------------
--  3D text of other scripts (qbx.drawText3d, QBCore.Functions.DrawText3D,
--  ESX.Game.Utils.DrawText3D – one line in those functions, see README).
--  Scripts call it every frame; all calls of one frame go to the NUI in one message.
--    'lafl'     label in the LAFL design at the position in the world
--    'textui'   text with a key -> LAFL text UI (nearest one); plain labels stay 'lafl'
--    'original' not handled -> returns false, the script draws its own text
-- ---------------------------------------------------------------------

local T3 = LibConfig.Text3DSettings or {}
local t3Pending, t3Thread, t3Parsed, t3Count = {}, false, {}, 0

--- "[E] - Exit | [G] - Manage" -> { { k = 'E', t = 'Exit' }, { k = 'G', t = 'Manage' } }
local function parse3d(text)
    local p = t3Parsed[text]
    if p then return p end
    p = { parts = {}, key = false }
    local raw = tostring(text):gsub('~n~', '\n'):gsub('\r', '')
    for part in (raw .. '|'):gmatch('(.-)[|\n]') do
        if part:match('%S') then
            local t, k = parseKeyText(part)
            p.parts[#p.parts + 1] = { k = k or false, t = t }
            if k then p.key = true end
        end
    end
    if t3Count > 500 then t3Parsed, t3Count = {}, 0 end     -- scripts with changing texts (timers ...)
    t3Parsed[text], t3Count = p, t3Count + 1
    return p
end

local function toCoords(a, b, c)
    if type(a) == 'number' then return vector3(a, b + 0.0, c + 0.0) end
    if type(a) == 'vector3' or type(a) == 'vector4' then return vector3(a.x, a.y, a.z) end
    if type(a) == 'table' and a.x then return vector3(a.x + 0.0, a.y + 0.0, a.z + 0.0) end
end

local function run3d()
    t3Thread = true
    CreateThread(function()
        local lastCall, shown = GetGameTimer(), false
        local maxDist = T3.maxDistance or 20.0
        local scaleCfg = T3.scale or 1.0
        while true do
            local list = t3Pending
            t3Pending = {}
            local now = GetGameTimer()
            if #list > 0 then lastCall = now end

            local items, seen, nth = {}, {}, {}
            if IsPauseMenuActive() then list = {} end
            local cam = GetFinalRenderedCamCoord()
            local ped = GetEntityCoords(PlayerPedId())
            local nearestKey, nearestD
            for _, e in ipairs(list) do
                local where = ('%s|%.2f|%.2f|%.2f'):format(e.text, e.coords.x, e.coords.y, e.coords.z)
                if not seen[where] then
                    seen[where] = true
                    nth[e.text] = (nth[e.text] or 0) + 1
                    local id = e.text .. '#' .. nth[e.text]     -- stable while the point moves
                    local p = e.parts and { parts = e.parts, key = true } or parse3d(e.text)
                    if not e.parts and LibConfig.Text3D == 'textui' and p.key then
                        local d = #(ped - e.coords)
                        if not nearestD or d < nearestD then nearestKey, nearestD = e.text, d end
                    else
                        local dist = #(cam - e.coords)
                        if dist <= maxDist then
                            local on, x, y = GetScreenCoordFromWorldCoord(e.coords.x, e.coords.y, e.coords.z)
                            if on then
                                local sc = math.max(0.6, math.min(1.1, 1.15 - dist * 0.035)) * scaleCfg
                                local op = dist > maxDist * 0.6 and math.max(0.0, 1.0 - (dist - maxDist * 0.6) / (maxDist * 0.4)) or 1.0
                                items[#items + 1] = { id = id, x = x, y = y, s = sc, o = op, parts = p.parts }
                            end
                        end
                    end
                end
            end
            if nearestKey then exports[GetCurrentResourceName()]:HelpText(nearestKey) end

            if #items > 0 or shown then
                send({ action = 'text3d', items = items })
                shown = #items > 0
            end
            if #list == 0 and not shown and now - lastCall > 1000 then break end
            Wait(0)
        end
        t3Thread = false
    end)
end

--- for core/textui_target.lua (Target = 'text3d'): label with ready parts, every frame
function LAFL_TargetLabel(coords, parts, id)
    t3Pending[#t3Pending + 1] = { coords = coords, text = id, parts = parts }
    if not t3Thread then run3d() end
end

--- exports.lafl_lib:DrawText3D({ coords = vec3, text = '...' }) | (coords, text) | (x, y, z, text)
--- Call it every frame like the GTA text. Returns false when LibConfig.Text3D = 'original'.
exports('DrawText3D', function(a, b, c, d)
    if LibConfig.Text3D ~= 'lafl' and LibConfig.Text3D ~= 'textui' then return false end
    local coords, text
    if type(a) == 'table' and a.coords then coords, text = toCoords(a.coords), a.text
    elseif type(a) == 'number' then coords, text = toCoords(a, b, c), d
    else coords, text = toCoords(a), b end
    if not coords or text == nil then return false end
    t3Pending[#t3Pending + 1] = { coords = coords, text = tostring(text) }
    if not t3Thread then run3d() end
    return true
end)

-- ---------------------------------------------------------------------
--  Dispatch
-- ---------------------------------------------------------------------

local function dispatch(coords, alert)
    alert = alert or {}
    if alert.chance and math.random(100) > alert.chance then return end
    coords = coords or GetEntityCoords(PlayerPedId())
    local system = LibConfig.Dispatch
    local street = LAFL.World.StreetName(coords)
    local title = alert.title or alert.message or 'Alert'
    local message = alert.message or alert.description or title

    if system == 'custom' then
        if CustomBridge.Dispatch then CustomBridge.Dispatch(coords, alert, street) end
        return
    end

    if system == 'lafl' then
        if GetResourceState('lafl_dispatch') ~= 'started' then
            print('^1[lafl_lib] LibConfig.Dispatch = lafl, but lafl_dispatch is not started^7')
            return
        end
        local data = {}
        for k, v in pairs(alert) do data[k] = v end
        data.coords, data.street = coords, street
        exports.lafl_dispatch:SendAlert(data)
        return
    end

    if system == 'ps-dispatch' then
        if GetResourceState('ps-dispatch') ~= 'started' then
            print('^1[lafl_lib] LibConfig.Dispatch = ps-dispatch, but ps-dispatch is not started^7')
            return
        end
        -- One alert with the fields of both versions: 1.x reads dispatchCode / description / sprite …,
        -- 2.x reads code / codeName / icon / priority / jobs. Unknown fields are ignored by each version.
        local data = {
            coords       = coords,
            message      = title,
            street       = street,
            -- 1.x
            dispatchCode = alert.code or '10-90',
            description  = message,
            radius       = alert.radius or 0,
            sprite       = alert.sprite or 161,
            color        = alert.color or 1,
            scale        = alert.scale or 1.0,
            length       = alert.length or 3,
            -- 2.x
            code         = alert.code or '10-90',
            codeName     = alert.codeName or 'lafl',
            icon         = alert.icon or 'fas fa-exclamation-triangle',
            priority     = alert.priority or 2,
            jobs         = alert.jobs or { 'leo' },
        }
        local ok, err = pcall(function() exports['ps-dispatch']:CustomAlert(data) end)
        if not ok then print(('^1[lafl_lib] ps-dispatch alert failed: %s^7'):format(tostring(err))) end
        return
    end

    if system == 'cd_dispatch' then
        if GetResourceState('cd_dispatch') ~= 'started' then
            print('^1[lafl_lib] LibConfig.Dispatch = cd_dispatch, but cd_dispatch is not started^7')
            return
        end
        local ok, err = pcall(function()
            local d = exports['cd_dispatch']:GetPlayerInfo()
            TriggerServerEvent('cd_dispatch:AddNotification', {
                job_table = alert.jobs or LibConfig.PoliceJobs,
                coords = coords,
                title = ('%s %s'):format(alert.code or '10-90', title),
                message = ('%s – %s'):format(message, d and d.street or street),
                flash = 0,
                unique_id = d and d.unique_id or tostring(math.random(100000, 999999)),
                sound = 1,
                blip = {
                    sprite = alert.sprite or 161, scale = alert.scale or 1.0, colour = alert.color or 1,
                    flashes = false, text = title, time = alert.length or 3, radius = alert.radius or 0,
                },
            })
        end)
        if not ok then print(('^1[lafl_lib] cd_dispatch alert failed: %s^7'):format(tostring(err))) end
        return
    end

    print(('^1[lafl_lib] Unknown LibConfig.Dispatch: %s^7'):format(tostring(system)))
end

exports('Dispatch', dispatch)
RegisterNetEvent('lafl_lib:dispatch', dispatch)

-- ---------------------------------------------------------------------
--  Minigames
-- ---------------------------------------------------------------------

local VALID = {
    lockpick = true, skillcheck = true, hack = true, thermite = true,
    safe = true, drill = true, wires = true, keypad = true,
}
local game = nil

local function runMinigame(name, opts)
    if game then return false end
    if not VALID[name] then
        print(('^1[lafl_lib] Unknown minigame: %s^7'):format(tostring(name)))
        return false
    end
    if not nuiReady then
        local timeout = GetGameTimer() + 5000
        while not nuiReady and GetGameTimer() < timeout do Wait(50) end
    end

    game = { p = promise.new() }
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    send({ action = 'minigame', game = name, opts = opts or {} })

    -- stop when the player dies
    local current = game
    CreateThread(function()
        while game == current do
            if IsEntityDead(PlayerPedId()) then
                send({ action = 'minigameStop' })
                current.p:resolve(false)
                break
            end
            Wait(250)
        end
    end)

    local result = Citizen.Await(game.p)
    SetNuiFocus(false, false)
    game = nil
    return result == true
end

-- Debug: every key the minigame receives is printed in F8 (LibConfig.Debug = true)
RegisterNUICallback('debugKey', function(data, cb)
    cb(1)
    if LibConfig.Debug and type(data) == 'table' then
        print(('[lafl_lib] key %-8s key=%s code=%s keyCode=%s%s'):format(tostring(data.type), tostring(data.key), tostring(data.code),
            tostring(data.keyCode), data.synthetic and ' (handled as press)' or ''))
    end
end)

RegisterNUICallback('minigameResult', function(data, cb)
    cb(1)
    if game then game.p:resolve(data and data.success == true) end
end)

exports('Minigame', runMinigame)
exports('MinigameActive', function() return game ~= nil end)
exports('StopMinigame', function()
    if not game then return end
    send({ action = 'minigameStop' })
    game.p:resolve(false)
end)

RegisterNetEvent('lafl_lib:minigame:start', function(token, name, opts)
    local ok = runMinigame(name, opts)
    TriggerServerEvent('lafl_lib:minigame:result', token, ok)
end)

-- ---------------------------------------------------------------------
--  Cleanup + debug
-- ---------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if game then SetNuiFocus(false, false) end
end)

if LibConfig.Debug then
    RegisterCommand('lafltest', function(_, args)
        local what = args[1] or 'notify'
        if what == 'notify' then
            for _, t in ipairs({ 'inform', 'success', 'warning', 'error' }) do
                notify(('Test notification (%s)'):format(t), t, { title = 'LAFL' })
            end
        elseif what == 'progress' then
            notify(tostring(runProgress({ duration = 5000, label = 'Test...' })), 'inform')
        elseif what == 'textui' then
            exports.lafl_lib:ShowTextUI('Test text UI', { key = 'E' })
            SetTimeout(4000, function() exports.lafl_lib:HideTextUI() end)
        elseif VALID[what] then
            local ok = runMinigame(what, { difficulty = args[2] or 'medium' })
            notify(ok and L.mg_success or L.mg_fail, ok and 'success' or 'error', { title = what })
        end
    end, false)
end
