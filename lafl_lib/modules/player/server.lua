-- =====================================================================
--  LAFL.Player (server)
-- =====================================================================

local Player = {}
local Core = LAFL.Core

local function fw() return LAFL.Config.Framework end

--- Raw framework player object (xPlayer / QB Player) or nil
function Player.Get(src)
    src = tonumber(src)
    if not src then return nil end
    if fw() == 'esx' then return Core.ESX().GetPlayerFromId(src) end
    if fw() == 'qb' then return Core.QB().Functions.GetPlayer(src) end
    return nil
end

--- Is the character loaded? (standalone: player is connected)
function Player.IsLoaded(src)
    if fw() == 'standalone' then return GetPlayerName(src) ~= nil end
    return Player.Get(src) ~= nil
end

--- Unique character ID (QB citizenid, ESX identifier). nil if not loaded.
function Player.GetIdentifier(src)
    local f = fw()
    if f == 'esx' then
        local xPlayer = Player.Get(src)
        return xPlayer and xPlayer.identifier or nil
    elseif f == 'qb' then
        local p = Player.Get(src)
        return p and p.PlayerData.citizenid or nil
    end
    local found, id = LAFL.Custom('GetIdentifier', src)
    if found and id then return id end
    return GetPlayerIdentifierByType(src, 'license') or ('src:' .. tostring(src))
end

--- Character name ('Max Muster'), falls back to the FiveM name
function Player.GetName(src)
    local f = fw()
    if f == 'esx' then
        local xPlayer = Player.Get(src)
        if xPlayer and xPlayer.getName then return xPlayer.getName() end
    elseif f == 'qb' then
        local p = Player.Get(src)
        local ci = p and p.PlayerData.charinfo
        if ci then return ('%s %s'):format(ci.firstname or '', ci.lastname or '') end
    else
        local found, name = LAFL.Custom('GetName', src)
        if found and name then return name end
    end
    return GetPlayerName(src) or ('#' .. tostring(src))
end

--- { name, label, grade, gradeLabel, onDuty, boss } or nil
function Player.GetJob(src)
    local f = fw()
    if f == 'esx' then
        local xPlayer = Player.Get(src)
        return xPlayer and Core.NormalizeJob(xPlayer.job) or nil
    elseif f == 'qb' then
        local p = Player.Get(src)
        return p and Core.NormalizeJob(p.PlayerData.job) or nil
    end
    local found, name, grade, onDuty = LAFL.Custom('GetJob', src)
    if found and name then
        return { name = name, label = name, grade = tonumber(grade) or 0, gradeLabel = '', onDuty = onDuty ~= false, boss = false }
    end
    return nil
end

--- { name, label, grade, gradeLabel, boss } or nil (QBCore gangs; standalone via custom)
function Player.GetGang(src)
    if fw() == 'qb' then
        local p = Player.Get(src)
        return p and Core.NormalizeGang(p.PlayerData.gang) or nil
    end
    local found, name, grade = LAFL.Custom('GetGang', src)
    if found and name then return { name = name, label = name, grade = tonumber(grade) or 0, gradeLabel = '', boss = false } end
    return nil
end

--- HasJob(src, 'police') / HasJob(src, { 'police', 'sheriff' }, 2) / HasJob(src, { police = 2 })
--- onDuty = true -> also requires on duty
function Player.HasJob(src, rule, minGrade, onDuty)
    local job = Player.GetJob(src)
    if not job or (onDuty and not job.onDuty) then return false end
    return Core.Matches(job, rule, minGrade)
end

function Player.HasGang(src, rule, minGrade)
    return Core.Matches(Player.GetGang(src), rule, minGrade)
end

--- Access rule like in lafl_crafting:
--- { jobs = { police = 0 }, gangs = { ballas = 2 }, items = { 'keycard' }, onDuty = true }
--- jobs OR gangs (if set) AND all items (if set)
function Player.HasAccess(src, access)
    if not access then return true end
    if access.jobs or access.gangs then
        local allowed = access.jobs and Player.HasJob(src, access.jobs, nil, access.onDuty) or false
        if not allowed and access.gangs then allowed = Player.HasGang(src, access.gangs) end
        if not allowed then return false end
    end
    for _, item in ipairs(access.items or {}) do
        if LAFL.Inventory.Count(src, item) < 1 then return false end
    end
    return true
end

--- All connected players (server ids)
function Player.List()
    local list = {}
    for _, id in ipairs(GetPlayers()) do list[#list + 1] = tonumber(id) end
    return list
end

--- Server id of an online character, or nil
function Player.FromIdentifier(identifier)
    if not identifier then return nil end
    for _, src in ipairs(Player.List()) do
        if Player.GetIdentifier(src) == identifier then return src end
    end
    return nil
end

--- Position of the player ped (vector3) or nil
function Player.Coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

return Player
