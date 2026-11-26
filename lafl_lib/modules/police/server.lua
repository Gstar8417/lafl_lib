-- =====================================================================
--  LAFL.Police (server)
-- =====================================================================

local Police = {}
local Core = LAFL.Core

local function isPoliceJob(name, jobs)
    for _, job in ipairs(jobs or LAFL.Config.PoliceJobs or {}) do
        if job == name then return true end
    end
    return false
end

--- Is this player police (and on duty, if LibConfig.PoliceOnDuty)?
function Police.IsPolice(src, jobs)
    local job = LAFL.Player.GetJob(src)
    if not job or not isPoliceJob(job.name, jobs) then return false end
    return not LAFL.Config.PoliceOnDuty or job.onDuty
end

--- Number of police players online. jobs = optional own job list.
function Police.Count(jobs)
    local fw = LAFL.Config.Framework
    local count = 0
    local onDutyOnly = LAFL.Config.PoliceOnDuty

    if fw == 'qb' then
        local QB = Core.QB()
        local players = (QB.Functions.GetQBPlayers and QB.Functions.GetQBPlayers()) or QB.Players or {}
        for _, p in pairs(players) do
            local job = p.PlayerData and p.PlayerData.job
            if job and isPoliceJob(job.name, jobs) and (not onDutyOnly or job.onduty) then count = count + 1 end
        end
    elseif fw == 'esx' then
        local ESX = Core.ESX()
        if ESX.GetExtendedPlayers then
            for _, xPlayer in pairs(ESX.GetExtendedPlayers()) do
                if xPlayer.job and isPoliceJob(xPlayer.job.name, jobs) then count = count + 1 end
            end
        else
            for _, id in ipairs(ESX.GetPlayers()) do
                local xPlayer = ESX.GetPlayerFromId(id)
                if xPlayer and xPlayer.job and isPoliceJob(xPlayer.job.name, jobs) then count = count + 1 end
            end
        end
    else
        local found, n = LAFL.Custom('CountPolice', jobs)
        if found then count = tonumber(n) or 0 end
    end
    return count
end

--- All police players online (server ids)
function Police.List(jobs)
    local list = {}
    for _, src in ipairs(LAFL.Player.List()) do
        if Police.IsPolice(src, jobs) then list[#list + 1] = src end
    end
    return list
end

return Police
