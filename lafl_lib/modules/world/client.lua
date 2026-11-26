-- =====================================================================
--  LAFL.World (client) – blips, models, peds / props with distance streaming
--
--  local id = LAFL.World.AddPed({
--      model = 's_m_m_linecook', coords = vec4(...), distance = 60.0,
--      scenario = 'WORLD_HUMAN_CLIPBOARD',        -- or anim = { dict, clip }
--      target = { { label = 'Reden', icon = 'fa-solid fa-comment', onSelect = fn } },
--      onSpawn = function(ped) end, onDespawn = function(ped) end,
--  })
--  LAFL.World.AddProp({ model = 'prop_washer_02', coords = vec4(...), target = {...} })
--  LAFL.World.Remove(id)       LAFL.World.Get(id) -> entity or nil
--  Everything is removed automatically when the script stops.
-- =====================================================================

local World = {}

local RES = LAFL.resource
local points, blips = {}, {}
local counter = 0
local running = false

-- ---------------------------------------------------------------------
--  Models + height
-- ---------------------------------------------------------------------

--- Load a model (name or hash). Returns the hash or nil.
function World.LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then
        print(('^1[%s] Model does not exist: %s^7'):format(RES, tostring(model)))
        return nil
    end
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

--- Height for peds: coords from coordinate commands are ~1 m above the ground.
--- Ground check is only used if it is close to the given height, otherwise z - 1.0
--- (prevents peds under the map in MLOs / on roofs).
function World.PedZ(c)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    if found and math.abs(groundZ - c.z) <= 2.5 then return groundZ end
    return c.z - 1.0
end

-- ---------------------------------------------------------------------
--  Single spawn (local, not networked)
-- ---------------------------------------------------------------------

function World.SpawnPed(model, coords, opts)
    opts = opts or {}
    local hash = World.LoadModel(model)
    if not hash then return nil end
    local z = opts.exactZ and coords.z or World.PedZ(coords)
    local ped = CreatePed(4, hash, coords.x, coords.y, z, coords.w or 0.0, opts.networked == true, false)
    SetModelAsNoLongerNeeded(hash)
    if opts.invincible ~= false then
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCanRagdoll(ped, false)
    end
    if opts.frozen ~= false then FreezeEntityPosition(ped, true) end
    if opts.scenario then
        TaskStartScenarioInPlace(ped, opts.scenario, 0, true)
    elseif opts.anim then
        LAFL.Anim.Play(opts.anim, ped)
    end
    return ped
end

function World.SpawnProp(model, coords, opts)
    opts = opts or {}
    local hash = World.LoadModel(model)
    if not hash then return nil end
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, opts.networked == true, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(obj, coords.w or opts.heading or 0.0)
    if opts.ground ~= false then PlaceObjectOnGroundProperly(obj) end
    if opts.frozen ~= false then FreezeEntityPosition(obj, true) end
    return obj
end

-- ---------------------------------------------------------------------
--  Streaming points
-- ---------------------------------------------------------------------

local function despawn(p)
    if not p.entity then return end
    if p.target then LAFL.Target.RemoveEntity(p.entity) end
    if p.onDespawn then pcall(p.onDespawn, p.entity) end
    if DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
    p.entity = nil
end

local function spawn(p)
    local entity
    if p.kind == 'ped' then
        entity = World.SpawnPed(p.model, p.coords, p)
    else
        entity = World.SpawnProp(p.model, p.coords, p)
    end
    if not entity then return end
    p.entity = entity
    if p.target then LAFL.Target.AddEntity(entity, p.target) end
    if p.onSpawn then pcall(p.onSpawn, entity) end
end

local function startLoop()
    if running then return end
    running = true
    CreateThread(function()
        while next(points) do
            local pc = GetEntityCoords(PlayerPedId())
            for _, p in pairs(points) do
                local near = #(pc - vec3(p.coords.x, p.coords.y, p.coords.z)) <= p.distance
                if near and not p.entity then
                    spawn(p)
                elseif not near and p.entity then
                    despawn(p)
                end
            end
            Wait(1000)
        end
        running = false
    end)
end

local function add(kind, data)
    counter = counter + 1
    local id = data.id or ('%s:%d'):format(kind, counter)
    if points[id] then World.Remove(id) end
    data.kind = kind
    data.distance = data.distance or 60.0
    points[id] = data
    startLoop()
    return id
end

function World.AddPed(data) return add('ped', data) end
function World.AddProp(data) return add('prop', data) end

function World.Remove(id)
    local p = points[id]
    if not p then return end
    despawn(p)
    points[id] = nil
end

function World.Get(id)
    local p = points[id]
    return p and p.entity or nil
end

-- ---------------------------------------------------------------------
--  Blips
-- ---------------------------------------------------------------------

--- cfg = { sprite, color, scale, label, shortRange = true, display = 4 }
function World.AddBlip(coords, cfg)
    cfg = cfg or {}
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, cfg.sprite or 1)
    SetBlipColour(blip, cfg.color or 0)
    SetBlipScale(blip, cfg.scale or 0.8)
    SetBlipDisplay(blip, cfg.display or 4)
    SetBlipAsShortRange(blip, cfg.shortRange ~= false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.label or RES)
    EndTextCommandSetBlipName(blip)
    blips[blip] = true
    return blip
end

--- Area blip (e.g. search zone). alpha 0-255
function World.AddRadiusBlip(coords, radius, color, alpha)
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, radius + 0.0)
    SetBlipColour(blip, color or 1)
    SetBlipAlpha(blip, alpha or 120)
    blips[blip] = true
    return blip
end

function World.RemoveBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    if blip then blips[blip] = nil end
end

-- ---------------------------------------------------------------------
--  Misc
-- ---------------------------------------------------------------------

--- Street name at coords: 'Strawberry Ave / Davis Ave'
function World.StreetName(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local a, b = GetStreetNameFromHashKey(s1), s2 ~= 0 and GetStreetNameFromHashKey(s2) or ''
    if b ~= '' then return a .. ' / ' .. b end
    return a
end

--- Coordinate command for Config.Debug: prints vec4 and copies it to the clipboard
function World.CoordsCommand(name)
    RegisterCommand(name, function()
        local ped = PlayerPedId()
        local text = LAFL.Format.Coords(GetEntityCoords(ped), GetEntityHeading(ped))
        print(text)
        exports[LAFL.name]:CopyText(text)
        LAFL.Notify(text, 'inform')
    end, false)
end

AddEventHandler('onResourceStop', function(name)
    if name ~= RES then return end
    for _, p in pairs(points) do pcall(despawn, p) end
    for blip in pairs(blips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
end)

return World
