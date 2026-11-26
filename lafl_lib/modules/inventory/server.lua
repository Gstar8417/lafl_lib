-- =====================================================================
--  LAFL.Inventory (server) – ox_inventory / qb-inventory / ESX / custom
-- =====================================================================

local Inventory = {}
local Core = LAFL.Core

local function inv() return LAFL.Config.Inventory end

local function qbPlayer(src) return Core.QB().Functions.GetPlayer(src) end
local function esxPlayer(src) return Core.ESX().GetPlayerFromId(src) end

local function itemBox(src, item, action, count)
    local data = Core.QB().Shared.Items[item]
    if data then TriggerClientEvent('qb-inventory:client:ItemBox', src, data, action, count) end
end

--- Amount of an item
function Inventory.Count(src, item)
    local i = inv()
    if i == 'ox' then
        return exports.ox_inventory:GetItemCount(src, item) or 0
    elseif i == 'qb' then
        local p = qbPlayer(src)
        if not p then return 0 end
        local total = 0
        for _, slot in pairs(p.PlayerData.items or {}) do
            if slot and slot.name == item then total = total + (slot.amount or slot.count or 0) end
        end
        return total
    elseif i == 'esx' then
        local xPlayer = esxPlayer(src)
        local data = xPlayer and xPlayer.getInventoryItem(item)
        return data and data.count or 0
    end
    local _, count = LAFL.Custom('GetItemCount', src, item)
    return tonumber(count) or 0
end

--- Has the player at least `count` of the item?
function Inventory.Has(src, item, count)
    return Inventory.Count(src, item) >= (count or 1)
end

--- Can the player carry this amount?
function Inventory.CanCarry(src, item, count, metadata)
    local i = inv()
    if i == 'ox' then
        return exports.ox_inventory:CanCarryItem(src, item, count, metadata) and true or false
    elseif i == 'qb' then
        -- newer qb-inventory versions have CanAddItem, older ones don't
        local ok, result = pcall(function() return exports['qb-inventory']:CanAddItem(src, item, count) end)
        if ok and result ~= nil then return result and true or false end
        return true
    elseif i == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return false end
        if xPlayer.canCarryItem then return xPlayer.canCarryItem(item, count) and true or false end
        return true
    end
    local _, ok = LAFL.Custom('CanCarry', src, item, count)
    return ok == true
end

--- Give an item (metadata: ox 'metadata' / qb 'info'). true on success.
function Inventory.Add(src, item, count, metadata)
    count = count or 1
    local i = inv()
    if i == 'ox' then
        return exports.ox_inventory:AddItem(src, item, count, metadata) and true or false
    elseif i == 'qb' then
        local p = qbPlayer(src)
        if not p then return false end
        local ok = p.Functions.AddItem(item, count, false, metadata)
        if ok then itemBox(src, item, 'add', count) end
        return ok and true or false
    elseif i == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return false end
        xPlayer.addInventoryItem(item, count)
        return true
    end
    local _, ok = LAFL.Custom('AddItem', src, item, count, metadata)
    return ok == true
end

--- Remove an item. Checks the amount first. slot / metadata optional (ox / qb).
function Inventory.Remove(src, item, count, metadata, slot)
    count = count or 1
    if not slot and Inventory.Count(src, item) < count then return false end
    local i = inv()
    if i == 'ox' then
        return exports.ox_inventory:RemoveItem(src, item, count, metadata, slot) and true or false
    elseif i == 'qb' then
        local p = qbPlayer(src)
        if not p then return false end
        local ok = p.Functions.RemoveItem(item, count, slot)
        if ok then itemBox(src, item, 'remove', count) end
        return ok and true or false
    elseif i == 'esx' then
        local xPlayer = esxPlayer(src)
        if not xPlayer then return false end
        xPlayer.removeInventoryItem(item, count)
        return true
    end
    local _, ok = LAFL.Custom('RemoveItem', src, item, count, metadata, slot)
    return ok == true
end

--- All slots of an item: { { slot, count, metadata }, ... } (ox / qb; esx / custom: one virtual slot)
function Inventory.Slots(src, item)
    local i, list = inv(), {}
    if i == 'ox' then
        for _, s in pairs(exports.ox_inventory:Search(src, 'slots', item) or {}) do
            list[#list + 1] = { slot = s.slot, count = s.count or 1, metadata = s.metadata or {} }
        end
    elseif i == 'qb' then
        local p = qbPlayer(src)
        for _, s in pairs(p and p.PlayerData.items or {}) do
            if s and s.name == item then
                list[#list + 1] = { slot = s.slot, count = s.amount or s.count or 1, metadata = s.info or {} }
            end
        end
    else
        local count = Inventory.Count(src, item)
        if count > 0 then list[1] = { count = count, metadata = {} } end
    end
    return list
end

--- Display name of an item (from the inventory, not translated)
local labelCache = {}
function Inventory.Label(item)
    if labelCache[item] then return labelCache[item] end
    local i = inv()
    local ok, label = pcall(function()
        if i == 'ox' then
            local data = exports.ox_inventory:Items(item)
            return data and data.label
        elseif i == 'qb' then
            local data = Core.QB().Shared.Items[item]
            return data and data.label
        elseif i == 'esx' then
            return Core.ESX().GetItemLabel(item)
        end
        local _, l = LAFL.Custom('GetItemLabel', item)
        return l
    end)
    label = (ok and label) or item
    labelCache[item] = label
    return label
end

--- Does the item exist in the inventory system?
function Inventory.Exists(item)
    local i = inv()
    local ok, exists = pcall(function()
        if i == 'ox' then return exports.ox_inventory:Items(item) ~= nil end
        if i == 'qb' then return Core.QB().Shared.Items[item] ~= nil end
        return true
    end)
    return ok and exists or false
end

return Inventory
