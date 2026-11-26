-- =====================================================================
--  LAFL.Core – framework objects + normalized job / gang data
-- =====================================================================

local Core = {}
local ESX, QB

function Core.ESX()
    if not ESX then ESX = exports['es_extended']:getSharedObject() end
    return ESX
end

function Core.QB()
    if not QB then QB = exports['qb-core']:GetCoreObject() end
    return QB
end

function Core.Framework() return LAFL.Config.Framework end
function Core.IsQB() return LAFL.Config.Framework == 'qb' end
function Core.IsESX() return LAFL.Config.Framework == 'esx' end

--- QB / ESX job table -> { name, label, grade, gradeLabel, onDuty, boss }
function Core.NormalizeJob(job)
    if type(job) ~= 'table' or not job.name then return nil end
    if type(job.grade) == 'table' then
        -- QBCore
        return {
            name       = job.name,
            label      = job.label or job.name,
            grade      = tonumber(job.grade.level) or 0,
            gradeLabel = job.grade.name or '',
            onDuty     = job.onduty ~= false,
            boss       = job.isboss == true,
        }
    end
    -- ESX
    return {
        name       = job.name,
        label      = job.label or job.name,
        grade      = tonumber(job.grade) or 0,
        gradeLabel = job.grade_label or job.grade_name or '',
        onDuty     = job.onDuty ~= false and job.onduty ~= false,
        boss       = job.grade_name == 'boss',
    }
end

--- QB gang table -> { name, label, grade, gradeLabel, boss }
function Core.NormalizeGang(gang)
    if type(gang) ~= 'table' or not gang.name or gang.name == 'none' then return nil end
    local grade = type(gang.grade) == 'table' and gang.grade or { level = gang.grade }
    return {
        name       = gang.name,
        label      = gang.label or gang.name,
        grade      = tonumber(grade.level) or 0,
        gradeLabel = grade.name or '',
        boss       = gang.isboss == true,
    }
end

--- Does job / gang data match a rule?
--- rule: 'police' | { 'police', 'sheriff' } | { police = 2, sheriff = 0 } (name = min grade)
function Core.Matches(data, rule, minGrade)
    if not data or rule == nil then return false end
    if type(rule) == 'string' then
        return data.name == rule and data.grade >= (minGrade or 0)
    end
    if type(rule) == 'table' then
        if rule[1] ~= nil then
            for _, name in ipairs(rule) do
                if data.name == name and data.grade >= (minGrade or 0) then return true end
            end
            return false
        end
        local min = rule[data.name]
        return min ~= nil and data.grade >= (tonumber(min) or 0)
    end
    return false
end

return Core
