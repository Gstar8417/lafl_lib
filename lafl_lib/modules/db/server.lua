-- =====================================================================
--  LAFL.DB (server) – oxmysql wrapper, every call waits for the result
--  With LibConfig.Database = 'none' all calls return empty results.
--
--  LAFL.DB.EnsureTable([[ CREATE TABLE IF NOT EXISTS ... ]])
--  local rows = LAFL.DB.Query('SELECT * FROM x WHERE owner = ?', { id })
--  local row  = LAFL.DB.Single(...)    local n = LAFL.DB.Scalar(...)
--  local id   = LAFL.DB.Insert(...)    local changed = LAFL.DB.Update(...)
-- =====================================================================

local DB = {}

function DB.Enabled()
    return LAFL.Config.Database == 'oxmysql'
end

--- Wait until oxmysql runs (max. 15 seconds). false if not available.
function DB.Ready()
    if not DB.Enabled() then return false end
    local timeout = GetGameTimer() + 15000
    while GetResourceState('oxmysql') ~= 'started' do
        if GetGameTimer() > timeout then
            print(('^1[%s] oxmysql is not started (LibConfig.Database = oxmysql)^7'):format(LAFL.resource))
            return false
        end
        Wait(100)
    end
    return true
end

local function await(fn, query, params)
    if not DB.Enabled() then return nil end
    local p = promise.new()
    local ok, err = pcall(function()
        exports.oxmysql[fn](exports.oxmysql, query, params or {}, function(result) p:resolve(result) end)
    end)
    if not ok then
        print(('^1[%s] Database error (is oxmysql started?): %s^7'):format(LAFL.resource, tostring(err)))
        p:resolve(nil)
    end
    return Citizen.Await(p)
end

function DB.Query(query, params)  return await('query', query, params) or {} end
function DB.Single(query, params) return await('single', query, params) end
function DB.Scalar(query, params) return await('scalar', query, params) end
function DB.Insert(query, params) return await('insert', query, params) end
function DB.Update(query, params) return await('update', query, params) or 0 end

--- Several queries at once: { { query, params }, ... } -> true / false
function DB.Transaction(queries)
    return await('transaction', queries) == true
end

--- Run CREATE TABLE IF NOT EXISTS ... once (waits for oxmysql)
function DB.EnsureTable(sql)
    if not DB.Ready() then return false end
    await('query', sql)
    return true
end

return DB
