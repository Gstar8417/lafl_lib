-- =====================================================================
--  LAFL.Target (client) – ox_target / qb-target
--
--  Options (same for every target type):
--  {
--      { name = 'wash', label = 'Waschmaschine benutzen', icon = 'fa-solid fa-soap',
--        distance = 2.0,                         -- optional (default LibConfig.InteractDistance)
--        canInteract = function(entity) return true end,
--        onSelect = function(entity) ... end },
--  }
--  Everything added here is removed automatically when the script stops.
--  LibConfig.Target = 'textui' / 'text3d': no target script needed – lafl_lib shows
--  "[E] label" near the interaction (core/textui_target.lua), in the text UI or as 3D label.
-- =====================================================================

local Target = {}

local RES = LAFL.resource
local zones, entities, models, globals = {}, {}, {}, {}
local counter = 0

local function system() return LAFL.Config.Target end
local function debugOn() return (type(Config) == 'table' and Config.Debug) or LAFL.Config.Debug or false end
local function defaultDist()
    return (type(Config) == 'table' and Config.InteractDistance) or LAFL.Config.InteractDistance or 2.0
end

local function prepare(options)
    for i, o in ipairs(options) do
        if not o.name then
            counter = counter + 1
            o.name = ('%s:%s'):format(RES, counter)
        end
        options[i] = o
    end
    return options
end

local function maxDistance(options)
    local d = 0
    for _, o in ipairs(options) do d = math.max(d, o.distance or defaultDist()) end
    return d
end

local function toOx(options)
    local list = {}
    for i, o in ipairs(options) do
        list[i] = {
            name = o.name,
            label = o.label,
            icon = o.icon,
            iconColor = o.iconColor,
            distance = o.distance or defaultDist(),
            canInteract = function(entity) return o.canInteract == nil or o.canInteract(entity) end,
            onSelect = function(data) o.onSelect(data and data.entity) end,
        }
    end
    return list
end

local function toQb(options)
    local list = {}
    for i, o in ipairs(options) do
        list[i] = {
            type = 'client',
            label = o.label,
            icon = o.icon,
            canInteract = function(entity) return o.canInteract == nil or o.canInteract(entity) end,
            action = function(entity) o.onSelect(entity) end,
        }
    end
    return list
end

local function textui() return system() == 'textui' or system() == 'text3d' end

--- options for the lafl_lib text UI target (functions stay in this script)
local function toText(options)
    local list = {}
    for i, o in ipairs(options) do
        list[i] = {
            name = o.name,
            label = o.label,
            distance = o.distance or defaultDist(),
            canInteract = o.canInteract and function(entity) return o.canInteract(entity) end or nil,
            onSelect = function(entity) o.onSelect(entity) end,
        }
    end
    return list
end

local function textAdd(kind, data, options)
    return exports[LAFL.name]:TextTargetAdd(kind, data, toText(options))
end

local function field(options, key)
    local list = {}
    for i, o in ipairs(options) do list[i] = o[key] end
    return list
end

-- ---------------------------------------------------------------------
--  Local entities (peds / props spawned by the script)
-- ---------------------------------------------------------------------

function Target.AddEntity(entity, options)
    prepare(options)
    if textui() then
        entities[entity] = { text = textAdd('entity', { entity = entity }, options), options = options }
        return
    elseif system() == 'qb' then
        exports['qb-target']:AddTargetEntity(entity, { options = toQb(options), distance = maxDistance(options) })
    else
        exports.ox_target:addLocalEntity(entity, toOx(options))
    end
    entities[entity] = options
end

function Target.RemoveEntity(entity)
    local options = entities[entity]
    if not options then return end
    if options.text then
        exports[LAFL.name]:TextTargetRemove(options.text)
        entities[entity] = nil
        return
    end
    if system() == 'qb' then
        exports['qb-target']:RemoveTargetEntity(entity, field(options, 'label'))
    else
        exports.ox_target:removeLocalEntity(entity, field(options, 'name'))
    end
    entities[entity] = nil
end

-- ---------------------------------------------------------------------
--  Models (every object / ped with this model, e.g. ATMs, safes)
-- ---------------------------------------------------------------------

--- Returns an id for RemoveModel
function Target.AddModel(modelList, options)
    if type(modelList) ~= 'table' then modelList = { modelList } end
    prepare(options)
    local text
    if textui() then
        text = textAdd('model', { models = modelList }, options)
    elseif system() == 'qb' then
        exports['qb-target']:AddTargetModel(modelList, { options = toQb(options), distance = maxDistance(options) })
    else
        exports.ox_target:addModel(modelList, toOx(options))
    end
    counter = counter + 1
    local id = 'model:' .. counter
    models[id] = { models = modelList, options = options, text = text }
    return id
end

function Target.RemoveModel(id)
    local m = models[id]
    if not m then return end
    if m.text then
        exports[LAFL.name]:TextTargetRemove(m.text)
        models[id] = nil
        return
    end
    if system() == 'qb' then
        exports['qb-target']:RemoveTargetModel(m.models, field(m.options, 'label'))
    else
        exports.ox_target:removeModel(m.models, field(m.options, 'name'))
    end
    models[id] = nil
end

-- ---------------------------------------------------------------------
--  Zones
-- ---------------------------------------------------------------------

--- Sphere zone. Returns an id for RemoveZone.
function Target.AddSphere(coords, radius, options)
    prepare(options)
    counter = counter + 1
    local name = ('%s_zone_%d'):format(RES, counter)
    local c = vec3(coords.x, coords.y, coords.z)
    local id

    if textui() then
        id = 'text:' .. textAdd('sphere', { coords = c, radius = radius }, options)
    elseif system() == 'qb' then
        exports['qb-target']:AddCircleZone(name, c, radius, { name = name, debugPoly = debugOn(), useZ = true },
            { options = toQb(options), distance = maxDistance(options) })
        id = name
    else
        id = exports.ox_target:addSphereZone({ coords = c, radius = radius, debug = debugOn(), options = toOx(options) })
    end
    zones[id] = true
    return id
end

--- Box zone. size = vec3(length, width, height). Returns an id for RemoveZone.
function Target.AddBox(coords, size, heading, options)
    prepare(options)
    counter = counter + 1
    local name = ('%s_zone_%d'):format(RES, counter)
    local c = vec3(coords.x, coords.y, coords.z)
    local id

    if textui() then
        id = 'text:' .. textAdd('box', { coords = c, size = size, heading = heading or 0.0 }, options)
    elseif system() == 'qb' then
        exports['qb-target']:AddBoxZone(name, c, size.x, size.y, {
            name = name, heading = heading or 0.0, debugPoly = debugOn(),
            minZ = c.z - size.z / 2, maxZ = c.z + size.z / 2,
        }, { options = toQb(options), distance = maxDistance(options) })
        id = name
    else
        id = exports.ox_target:addBoxZone({ coords = c, size = size, rotation = heading or 0.0, debug = debugOn(), options = toOx(options) })
    end
    zones[id] = true
    return id
end

function Target.RemoveZone(id)
    if not id or not zones[id] then return end
    if type(id) == 'string' and id:sub(1, 5) == 'text:' then
        exports[LAFL.name]:TextTargetRemove(tonumber(id:sub(6)))
        zones[id] = nil
        return
    end
    if system() == 'qb' then
        exports['qb-target']:RemoveZone(id)
    else
        exports.ox_target:removeZone(id)
    end
    zones[id] = nil
end

-- ---------------------------------------------------------------------
--  Global: every vehicle / ped / player
-- ---------------------------------------------------------------------

local globalTypes = {
    vehicle = { ox = { 'addGlobalVehicle', 'removeGlobalVehicle' }, qb = { 'AddGlobalVehicle', 'RemoveGlobalVehicle' } },
    ped     = { ox = { 'addGlobalPed', 'removeGlobalPed' },         qb = { 'AddGlobalPed', 'RemoveGlobalPed' } },
    player  = { ox = { 'addGlobalPlayer', 'removeGlobalPlayer' },   qb = { 'AddGlobalPlayer', 'RemoveGlobalPlayer' } },
}

--- kind = 'vehicle' | 'ped' | 'player'. Returns an id for RemoveGlobal.
function Target.AddGlobal(kind, options)
    local t = globalTypes[kind]
    if not t then error('LAFL.Target.AddGlobal: unknown type ' .. tostring(kind), 2) end
    prepare(options)
    local text
    if textui() then
        text = textAdd('global', { kind = kind }, options)
    elseif system() == 'qb' then
        exports['qb-target'][t.qb[1]](exports['qb-target'], { options = toQb(options), distance = maxDistance(options) })
    else
        exports.ox_target[t.ox[1]](exports.ox_target, toOx(options))
    end
    counter = counter + 1
    local id = 'global:' .. counter
    globals[id] = { kind = kind, options = options, text = text }
    return id
end

function Target.RemoveGlobal(id)
    local g = globals[id]
    if not g then return end
    if g.text then
        exports[LAFL.name]:TextTargetRemove(g.text)
        globals[id] = nil
        return
    end
    local t = globalTypes[g.kind]
    if system() == 'qb' then
        exports['qb-target'][t.qb[2]](exports['qb-target'], field(g.options, 'label'))
    else
        exports.ox_target[t.ox[2]](exports.ox_target, field(g.options, 'name'))
    end
    globals[id] = nil
end

-- ---------------------------------------------------------------------
--  Cleanup when the script stops
-- ---------------------------------------------------------------------

AddEventHandler('onResourceStop', function(name)
    if name ~= RES then return end
    for id in pairs(zones) do pcall(Target.RemoveZone, id) end
    for entity in pairs(entities) do pcall(Target.RemoveEntity, entity) end
    for id in pairs(models) do pcall(Target.RemoveModel, id) end
    for id in pairs(globals) do pcall(Target.RemoveGlobal, id) end
end)

return Target
