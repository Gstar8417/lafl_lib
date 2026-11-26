-- =====================================================================
--  LAFL.Anim (client)
--  anim = { dict = '...', clip = '...', flag = 1 } or { scenario = '...' }
-- =====================================================================

local Anim = {}

function Anim.LoadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dict)
end

function Anim.Play(anim, ped)
    if not anim then return end
    ped = ped or PlayerPedId()
    if anim.scenario then
        TaskStartScenarioInPlace(ped, anim.scenario, 0, true)
    elseif anim.dict and Anim.LoadDict(anim.dict) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, anim.duration or -1, anim.flag or 1, 0, false, false, false)
    end
end

function Anim.IsPlaying(anim, ped)
    if not anim or not anim.dict then return true end
    return IsEntityPlayingAnim(ped or PlayerPedId(), anim.dict, anim.clip, 3)
end

function Anim.Stop(ped)
    ClearPedTasks(ped or PlayerPedId())
end

--- Attach a prop to the ped. prop = { model, bone = 57005, pos = vec3, rot = vec3 }. Returns the entity.
function Anim.AttachProp(prop, ped)
    ped = ped or PlayerPedId()
    local model = LAFL.World.LoadModel(prop.model)
    if not model then return nil end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(model, c.x, c.y, c.z + 0.2, true, true, false)
    local pos, rot = prop.pos or vec3(0.0, 0.0, 0.0), prop.rot or vec3(0.0, 0.0, 0.0)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, prop.bone or 57005), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
    return obj
end

return Anim
