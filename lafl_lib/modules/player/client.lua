-- =====================================================================
--  LAFL.Player (client)
-- =====================================================================

local Player = {}
local Core = LAFL.Core

local function fw() return LAFL.Config.Framework end

--- Raw framework player data
function Player.Data()
    local f = fw()
    if f == 'esx' then return Core.ESX().GetPlayerData() or {} end
    if f == 'qb' then return Core.QB().Functions.GetPlayerData() or {} end
    local found, data = LAFL.Custom('GetPlayerData')
    return found and data or {}
end

function Player.IsLoaded()
    local f = fw()
    if f == 'esx' then return Core.ESX().IsPlayerLoaded and Core.ESX().IsPlayerLoaded() or Player.Data().job ~= nil end
    if f == 'qb' then return LocalPlayer.state.isLoggedIn == true or Player.Data().citizenid ~= nil end
    return true
end

function Player.GetJob()
    if fw() == 'standalone' then
        local found, name, grade, onDuty = LAFL.Custom('GetJob')
        if found and name then return { name = name, label = name, grade = tonumber(grade) or 0, gradeLabel = '', onDuty = onDuty ~= false, boss = false } end
        return nil
    end
    return Core.NormalizeJob(Player.Data().job)
end

function Player.GetGang()
    if fw() == 'standalone' then
        local found, name, grade = LAFL.Custom('GetGang')
        if found and name then return { name = name, label = name, grade = tonumber(grade) or 0, gradeLabel = '', boss = false } end
        return nil
    end
    return Core.NormalizeGang(Player.Data().gang)
end

function Player.HasJob(rule, minGrade, onDuty)
    local job = Player.GetJob()
    if not job or (onDuty and not job.onDuty) then return false end
    return Core.Matches(job, rule, minGrade)
end

function Player.HasGang(rule, minGrade)
    return Core.Matches(Player.GetGang(), rule, minGrade)
end

-- ---------------------------------------------------------------------
--  Events: LAFL.Player.OnLoaded(fn), OnUnloaded(fn), OnJobChange(fn(job))
-- ---------------------------------------------------------------------

function Player.OnLoaded(fn)
    local f = fw()
    if f == 'qb' then RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() fn() end)
    elseif f == 'esx' then RegisterNetEvent('esx:playerLoaded', function() fn() end) end
    AddEventHandler('lafl_lib:playerLoaded', function() fn() end)   -- standalone: trigger this yourself
end

function Player.OnUnloaded(fn)
    local f = fw()
    if f == 'qb' then RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() fn() end)
    elseif f == 'esx' then RegisterNetEvent('esx:onPlayerLogout', function() fn() end) end
    AddEventHandler('lafl_lib:playerUnloaded', function() fn() end)
end

function Player.OnJobChange(fn)
    local f = fw()
    if f == 'qb' then
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) fn(Core.NormalizeJob(job)) end)
        RegisterNetEvent('QBCore:Client:SetDuty', function() fn(Player.GetJob()) end)
    elseif f == 'esx' then
        RegisterNetEvent('esx:setJob', function(job) fn(Core.NormalizeJob(job)) end)
    end
end

return Player
