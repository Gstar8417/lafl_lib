-- =====================================================================
--  QBCore progressbar replacement (lafl_lib/extras)
--  Same API as qbcore-framework/progressbar – QBCore.Functions.Progressbar
--  uses it automatically:
--    exports['progressbar']:Progress(action, function(cancelled) end)
--    ProgressWithStartEvent / ProgressWithTickEvent / ProgressWithStartAndTick
--    isDoingSomething()
--    events progressbar:client:progress / :ProgressWithStartEvent / :ProgressWithTickEvent /
--           :ProgressWithStartAndTick / :cancel / :ToggleBusyness
--  action = { name, duration, label, useWhileDead, canCancel, controlDisables = {...},
--             animation = { animDict, anim, flags } | { task }, prop = {...}, propTwo = {...} }
--  Cancel: X (lafl_lib).
-- =====================================================================

local LIB = 'lafl_lib'
local busy = false
local current = nil

local function useLib()
    if GetResourceState(LIB) ~= 'started' then return false end
    local ok, modes = pcall(function() return exports[LIB]:GetUIModes() end)
    return ok and type(modes) == 'table' and modes.progress ~= 'qb'
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(5) end
    return HasModelLoaded(hash) and hash or nil
end

--- second prop (lafl_lib attaches only one)
local function attachProp(prop, ped)
    if type(prop) ~= 'table' or not prop.model then return nil end
    local hash = loadModel(prop.model)
    if not hash then return nil end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z, true, true, true)
    local pos, rot = prop.coords or vec3(0.0, 0.0, 0.0), prop.rotation or vec3(0.0, 0.0, 0.0)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, prop.bone or 60309), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, true, 0, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function toLafl(action)
    local anim
    local a = action.animation
    if type(a) == 'table' then
        if a.task then
            anim = { scenario = a.task }
        elseif a.animDict and a.anim then
            anim = { dict = a.animDict, clip = a.anim, flag = (a.flags and a.flags ~= 0) and a.flags or 1 }
        end
    end
    local prop
    if type(action.prop) == 'table' and action.prop.model then
        prop = { model = action.prop.model, bone = action.prop.bone or 60309, pos = action.prop.coords, rot = action.prop.rotation }
    end
    local cd = action.controlDisables or {}
    return {
        duration = tonumber(action.duration) or 3000,
        label = action.label or '',
        canCancel = action.canCancel == true,
        anim = anim,
        prop = prop,
        disable = {
            move = cd.disableMovement == true, car = cd.disableCarMovement == true,
            mouse = cd.disableMouse == true, combat = cd.disableCombat == true,
        },
    }
end

--- fallback without lafl_lib: GTA help box with percent, X cancels
local function nativeProgress(run, action)
    local duration = tonumber(action.duration) or 3000
    local endTime = GetGameTimer() + duration
    while GetGameTimer() < endTime do
        Wait(0)
        if run.cancelled or (IsEntityDead(PlayerPedId()) and not action.useWhileDead)
            or (action.canCancel and IsControlJustPressed(0, 73)) then return false end
        local pct = math.floor((1.0 - (endTime - GetGameTimer()) / duration) * 100)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(('%s ~b~%d%%~s~'):format(action.label or '', pct))
        EndTextCommandDisplayHelp(0, false, false, -1)
    end
    return true
end

local function StartProgress(action, onStart, onTick, onFinish)
    if type(action) ~= 'table' or busy then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) and not action.useWhileDead then return end

    busy = true
    local run = { cancelled = false }
    current = run
    LocalPlayer.state:set('inv_busy', true, true)

    CreateThread(function()
        if onStart then onStart() end
        if onTick then
            CreateThread(function()
                while current == run do onTick() Wait(0) end
            end)
        end

        local second = attachProp(action.propTwo, ped)
        local ok
        if useLib() then
            ok = exports[LIB]:Progress(toLafl(action)) == true
        else
            ok = nativeProgress(run, action)
        end
        if second and DoesEntityExist(second) then DetachEntity(second, true, true) DeleteObject(second) end

        if current == run then current = nil end
        busy = false
        LocalPlayer.state:set('inv_busy', false, true)
        if onFinish then onFinish(not ok) end     -- QBCore: finish(wasCancelled)
    end)
end

local function Cancel()
    if not current then return end
    current.cancelled = true
    if GetResourceState(LIB) == 'started' then pcall(function() exports[LIB]:CancelProgress() end) end
end

-- Events (same names as the original)
RegisterNetEvent('progressbar:client:ToggleBusyness', function(bool) busy = bool == true end)
RegisterNetEvent('progressbar:client:progress', function(action, finish) StartProgress(action, nil, nil, finish) end)
RegisterNetEvent('progressbar:client:ProgressWithStartEvent', function(action, start, finish) StartProgress(action, start, nil, finish) end)
RegisterNetEvent('progressbar:client:ProgressWithTickEvent', function(action, tick, finish) StartProgress(action, nil, tick, finish) end)
RegisterNetEvent('progressbar:client:ProgressWithStartAndTick', function(action, start, tick, finish) StartProgress(action, start, tick, finish) end)
RegisterNetEvent('progressbar:client:cancel', Cancel)

-- Exports (same names as the original)
exports('Progress', function(action, finish) StartProgress(action, nil, nil, finish) end)
exports('ProgressWithStartEvent', function(action, start, finish) StartProgress(action, start, nil, finish) end)
exports('ProgressWithTickEvent', function(action, tick, finish) StartProgress(action, nil, tick, finish) end)
exports('ProgressWithStartAndTick', function(action, start, tick, finish) StartProgress(action, start, tick, finish) end)
exports('isDoingSomething', function() return busy end)
