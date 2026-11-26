-- =====================================================================
--  esx_progressbar replacement (lafl_lib/extras)
--  Same API as the original esx_progressbar:
--    exports['esx_progressbar']:Progressbar(message, length, {
--        FreezePlayer = true,
--        animation = { type = 'anim', dict = '...', lib = '...' } | { type = 'Scenario', Scenario = '...' },
--        onFinish = function() end, onCancel = function() end,
--    }) -> true if started
--    exports['esx_progressbar']:CancelProgressbar()
--  ESX.Progressbar / ESX.CancelProgressbar use it automatically.
--  Cancel: X (lafl_lib) or Backspace (same key mapping as the original).
-- =====================================================================

local LIB = 'lafl_lib'
local current = nil

local function useLib()
    if GetResourceState(LIB) ~= 'started' then return false end
    local ok, modes = pcall(function() return exports[LIB]:GetUIModes() end)
    return ok and type(modes) == 'table' and modes.progress ~= 'esx'
end

--- fallback without lafl_lib: GTA help box with percent, X cancels
local function nativeProgress(run, message, length)
    local endTime = GetGameTimer() + length
    while GetGameTimer() < endTime do
        Wait(0)
        if run.cancelled or IsEntityDead(PlayerPedId()) or IsControlJustPressed(0, 73) then return false end
        local pct = math.floor((1.0 - (endTime - GetGameTimer()) / length) * 100)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(('%s ~b~%d%%~s~'):format(message, pct))
        EndTextCommandDisplayHelp(0, false, false, -1)
    end
    return true
end

---@param message string
---@param length? number ms
---@param Options? table
---@return boolean started
local function Progressbar(message, length, Options)
    if current then return false end
    Options = Options or {}
    message = message ~= nil and tostring(message) or ''
    length = tonumber(length) or 3000

    local run = { options = Options }
    current = run

    CreateThread(function()
        local ped = PlayerPedId()
        local freeze = Options.FreezePlayer == true
        local ok

        if useLib() then
            local anim
            local a = Options.animation
            if type(a) == 'table' then
                if a.type == 'anim' and a.dict and a.lib then
                    anim = { dict = a.dict, clip = a.lib, flag = 1 }
                elseif a.type == 'Scenario' and a.Scenario then
                    anim = { scenario = a.Scenario }
                end
            end
            if freeze then FreezeEntityPosition(ped, true) end
            ok = exports[LIB]:Progress({
                duration = length, label = message, anim = anim, canCancel = true,
                disable = { move = freeze, car = freeze, combat = true },
            }) == true
            if freeze then FreezeEntityPosition(ped, false) end
        else
            local a = Options.animation
            if type(a) == 'table' and a.type == 'Scenario' and a.Scenario then TaskStartScenarioInPlace(ped, a.Scenario, 0, true) end
            if freeze then FreezeEntityPosition(ped, true) end
            ok = nativeProgress(run, message, length)
            if freeze then FreezeEntityPosition(ped, false) end
            ClearPedTasks(ped)
        end

        if current ~= run then return end     -- already cancelled by CancelProgressbar
        current = nil
        if ok then
            if Options.onFinish then Options.onFinish() end
        elseif Options.onCancel then
            Options.onCancel()
        end
    end)

    return true
end

local function CancelProgressbar()
    if not current then return end
    local run = current
    current = nil
    run.cancelled = true
    if GetResourceState(LIB) == 'started' then pcall(function() exports[LIB]:CancelProgress() end) end
    if run.options.FreezePlayer then FreezeEntityPosition(PlayerPedId(), false) end
    if run.options.onCancel then run.options.onCancel() end
end

exports('Progressbar', Progressbar)
exports('CancelProgressbar', CancelProgressbar)

-- same key mapping name as the original, so players keep their key setting
RegisterCommand('cancelprog', CancelProgressbar, false)
RegisterKeyMapping('cancelprog', '[ProgressBar] Cancel Progressbar', 'keyboard', 'BACK')
