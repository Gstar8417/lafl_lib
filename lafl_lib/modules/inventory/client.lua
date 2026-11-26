-- =====================================================================
--  LAFL.Inventory (client) – for canInteract checks and menu images
--  (the server always checks again)
-- =====================================================================

local Inventory = {}
local Core = LAFL.Core

function Inventory.Count(item)
    local i = LAFL.Config.Inventory
    if i == 'ox' then
        return exports.ox_inventory:Search('count', item) or 0
    elseif i == 'qb' then
        local total = 0
        for _, s in pairs(Core.QB().Functions.GetPlayerData().items or {}) do
            if s and s.name == item then total = total + (s.amount or s.count or 0) end
        end
        return total
    elseif i == 'esx' then
        for _, s in pairs(Core.ESX().GetPlayerData().inventory or {}) do
            if s.name == item then return s.count or 0 end
        end
        return 0
    end
    local _, count = LAFL.Custom('ClientItemCount', item)
    return tonumber(count) or 0
end

function Inventory.Has(item, count)
    return Inventory.Count(item) >= (count or 1)
end

--- Image path pattern for the NUI ('%s' = item name) or false
function Inventory.ImagePath()
    local path
    if type(Config) == 'table' then path = Config.ImagePath end
    if path == nil then path = LAFL.Config.ImagePath end
    if path ~= nil then return path end
    local i = LAFL.Config.Inventory
    if i == 'ox' then return 'nui://ox_inventory/web/images/%s.png' end
    if i == 'qb' then return 'nui://qb-inventory/html/images/%s.png' end
    return false
end

function Inventory.Image(item)
    local path = Inventory.ImagePath()
    return path and path:format(item) or nil
end

return Inventory
