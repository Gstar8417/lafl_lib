-- =====================================================================
--  LAFL LIB – target without ox_target / qb-target (LibConfig.Target = 'textui' / 'text3d')
--
--  Every script registers its interactions through LAFL.Target as usual.
--  In 'textui' mode they all end up here: one loop finds the nearest
--  interaction of all scripts and shows "[E] label" with the text UI.
--  More than one option: switch with the mouse wheel or the arrow keys.
-- =====================================================================

if LibConfig.Target ~= 'textui' and LibConfig.Target ~= 'text3d' then return end
local AS_3D = LibConfig.Target == 'text3d'     -- label in the world instead of the text UI

local S = LibConfig.TextTargetSettings or {}
local KEY        = S.key or 38            -- E
local KEY_LABEL  = S.keyLabel or 'E'
local SCAN_MS    = S.scanInterval or 200
local DEF_DIST   = LibConfig.InteractDistance or 2.0
local VEH_DIST   = S.vehicleDistance or 3.0

local entries = {}     -- id -> entry
local counter = 0

-- ---------------------------------------------------------------------
--  Registration (called by modules/target/client.lua of every script)
-- ---------------------------------------------------------------------

local function hashList(models)
    local set = {}
    if type(models) ~= 'table' then models = { models } end
    for _, m in ipairs(models) do set[type(m) == 'number' and m or joaat(m)] = true end
    return set
end

exports('TextTargetAdd', function(kind, data, options)
    counter = counter + 1
    local e = {
        id = counter,
        resource = GetInvokingResource() or GetCurrentResourceName(),
        kind = kind,
        options = options or {},
    }
    if kind == 'entity' then
        e.entity = data.entity
    elseif kind == 'model' then
        e.models = hashList(data.models)
    elseif kind == 'sphere' then
        e.coords = vec3(data.coords.x, data.coords.y, data.coords.z)
        e.radius = data.radius or 1.5
    elseif kind == 'box' then
        e.coords = vec3(data.coords.x, data.coords.y, data.coords.z)
        e.size = data.size
        e.heading = data.heading or 0.0
    elseif kind == 'global' then
        e.global = data.kind      -- 'vehicle' | 'ped' | 'player'
    end
    entries[counter] = e
    return counter
end)

exports('TextTargetRemove', function(id)
    entries[id] = nil
end)

-- scripts that stop lose all their interactions
AddEventHandler('onResourceStop', function(res)
    for id, e in pairs(entries) do
        if e.resource == res then entries[id] = nil end
    end
end)

-- ---------------------------------------------------------------------
--  Finding the nearest interaction
-- ---------------------------------------------------------------------

local function optDist(o) return o.distance or DEF_DIST end

local function inBox(e, p)
    local h = math.rad(-(e.heading or 0.0))
    local dx, dy = p.x - e.coords.x, p.y - e.coords.y
    local lx = dx * math.cos(h) - dy * math.sin(h)
    local ly = dx * math.sin(h) + dy * math.cos(h)
    return math.abs(lx) <= e.size.x / 2 and math.abs(ly) <= e.size.y / 2 and math.abs(p.z - e.coords.z) <= e.size.z / 2
end

--- usable options of one entry for this entity (canInteract checked)
local function usable(e, entity, dist)
    local list = {}
    for _, o in ipairs(e.options) do
        if (dist == nil or dist <= optDist(o)) then
            local ok = true
            if o.canInteract then
                local s, r = pcall(o.canInteract, entity)
                ok = s and r ~= false and r ~= nil
            end
            if ok then list[#list + 1] = o end
        end
    end
    return list
end

local function nearestFromPool(pool, pc, maxDist, filter)
    local best, bestD
    for _, ent in ipairs(GetGamePool(pool)) do
        if (not filter or filter(ent)) then
            local d = #(pc - GetEntityCoords(ent))
            if d <= maxDist and (not bestD or d < bestD) then best, bestD = ent, d end
        end
    end
    return best, bestD
end

local function maxOptDist(e)
    local m = 0
    for _, o in ipairs(e.options) do m = math.max(m, optDist(o)) end
    return m
end

local function scan()
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local cands = {}    -- { dist, entity, options }

    local function push(d, entity, opts, at)
        if #opts > 0 then cands[#cands + 1] = { dist = d, entity = entity, options = opts, at = at } end
    end

    local modelSets = {}
    for _, e in pairs(entries) do
        if e.kind == 'entity' then
            if e.entity and DoesEntityExist(e.entity) then
                local d = #(pc - GetEntityCoords(e.entity))
                if d <= maxOptDist(e) then push(d, e.entity, usable(e, e.entity, d)) end
            end
        elseif e.kind == 'sphere' then
            local d = #(pc - e.coords)
            if d <= e.radius + 0.5 then push(d, nil, usable(e, nil, nil), e.coords) end
        elseif e.kind == 'box' then
            if inBox(e, pc) then push(#(pc - e.coords), nil, usable(e, nil, nil), e.coords) end
        elseif e.kind == 'model' then
            modelSets[#modelSets + 1] = e
        elseif e.kind == 'global' then
            if e.global == 'vehicle' then
                local veh, d = nearestFromPool('CVehicle', pc, math.max(maxOptDist(e), VEH_DIST))
                if veh then push(d, veh, usable(e, veh, d)) end
            elseif e.global == 'ped' then
                local p, d = nearestFromPool('CPed', pc, maxOptDist(e), function(x) return x ~= ped and not IsPedAPlayer(x) end)
                if p then push(d, p, usable(e, p, d)) end
            elseif e.global == 'player' then
                local p, d = nearestFromPool('CPed', pc, maxOptDist(e), function(x) return x ~= ped and IsPedAPlayer(x) end)
                if p then push(d, p, usable(e, p, d)) end
            end
        end
    end

    -- models: objects, peds and vehicles with a registered model nearby
    if #modelSets > 0 then
        for _, pool in ipairs({ 'CObject', 'CPed', 'CVehicle' }) do
            for _, ent in ipairs(GetGamePool(pool)) do
                local d = #(pc - GetEntityCoords(ent))
                if d <= 6.0 then
                    local hash = GetEntityModel(ent)
                    for _, e in ipairs(modelSets) do
                        if e.models[hash] and d <= maxOptDist(e) then push(d, ent, usable(e, ent, d)) end
                    end
                end
            end
        end
    end

    -- nearest target wins; all its usable options are offered
    table.sort(cands, function(a, b) return a.dist < b.dist end)
    local first = cands[1]
    if not first then return nil end
    local opts = {}
    for _, c in ipairs(cands) do
        if c.entity == first.entity and math.abs(c.dist - first.dist) < 0.05 then
            for _, o in ipairs(c.options) do opts[#opts + 1] = o end
        end
    end
    return { entity = first.entity, options = opts, at = first.at }
end

-- ---------------------------------------------------------------------
--  Loop: scan a few times per second, read keys every frame while shown
-- ---------------------------------------------------------------------

local current, selected, shownText = nil, 1, nil
local blockedUntil = 0

local LIB = GetCurrentResourceName()

local function hide()
    if shownText then
        -- only hide our own text, never the hint of another script
        if exports[LIB]:TextUIOwner() == 'target' then exports[LIB]:HideTextUI() end
        shownText = nil
    end
end

--- another script shows its own hint (sitting, trunk, placing ...): pause meanwhile
local function otherTextUI()
    local owner = exports[LIB]:TextUIOwner()
    return owner ~= nil and owner ~= 'target'
end

--- where the 3D label hangs: above the entity (model height) or at the zone centre
local function labelCoords(target)
    if target.entity and DoesEntityExist(target.entity) then
        local c = GetEntityCoords(target.entity)
        local _, max = GetModelDimensions(GetEntityModel(target.entity))
        return vector3(c.x, c.y, c.z + math.min(math.max(max.z, 0.3), 2.5) + 0.15)
    end
    if target.at then return vector3(target.at.x, target.at.y, target.at.z + 0.3) end
    local c = GetEntityCoords(PlayerPedId())
    return vector3(c.x, c.y, c.z + 0.5)
end

local function show()
    local o = current.options[selected]
    local text = o.label or '?'
    if #current.options > 1 then text = ('%s   ⇅ %d/%d'):format(text, selected, #current.options) end
    if AS_3D then
        LAFL_TargetLabel(labelCoords(current), { { k = KEY_LABEL, t = text } }, 'target:' .. text)
        return
    end
    if text ~= shownText then
        exports[LIB]:ShowTextUI(text, { key = KEY_LABEL, __target = true })
        shownText = text
    end
end

local function blocked()
    local ped = PlayerPedId()
    return IsPedDeadOrDying(ped, true) or IsPauseMenuActive() or IsNuiFocused() or GetGameTimer() < blockedUntil or otherTextUI()
end

CreateThread(function()
    local nextScan = 0
    while true do
        if not next(entries) then
            hide(); current = nil
            Wait(500)
        else
            local now = GetGameTimer()
            if now >= nextScan then
                nextScan = now + SCAN_MS
                local found = (not blocked()) and scan() or nil
                if found then
                    local same = current and current.entity == found.entity and #current.options == #found.options
                    current = found
                    if not same then selected = 1 end
                    if selected > #current.options then selected = 1 end
                else
                    current = nil
                end
            end

            if current and otherTextUI() then
                current = nil
                shownText = nil
            end

            if current then
                show()
                if #current.options > 1 then
                    -- mouse wheel / arrow keys switch the option (weapon wheel is blocked meanwhile)
                    DisableControlAction(0, 14, true); DisableControlAction(0, 15, true)
                    DisableControlAction(0, 16, true); DisableControlAction(0, 17, true)
                    if IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) or IsControlJustPressed(0, 172) then
                        selected = selected > 1 and selected - 1 or #current.options
                    elseif IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) or IsControlJustPressed(0, 173) then
                        selected = selected < #current.options and selected + 1 or 1
                    end
                end
                if IsControlJustReleased(0, KEY) then
                    local o = current.options[selected]
                    local entity = current.entity
                    blockedUntil = GetGameTimer() + 600
                    current = nil
                    hide()
                    if o and o.onSelect then
                        CreateThread(function()
                            local ok, err = pcall(o.onSelect, entity)
                            if not ok then print(('^1[lafl_lib] target action failed: %s^7'):format(tostring(err))) end
                        end)
                    end
                end
                Wait(0)
            else
                hide()
                Wait(100)
            end
        end
    end
end)
