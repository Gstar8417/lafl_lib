-- =====================================================================
--  CUSTOM SYSTEMS (server)
--  Only used when 'custom' / 'standalone' is selected in lafl_lib/config.lua.
--  Applies to ALL LAFL scripts at once.
-- =====================================================================

CustomBridge = {}

-- ---------------------------------------------------------------------
--  Inventory (LibConfig.Inventory = 'custom')
-- ---------------------------------------------------------------------

function CustomBridge.GetItemCount(src, item)
    return 0
end

function CustomBridge.CanCarry(src, item, count)
    return true
end

--- true on success
function CustomBridge.AddItem(src, item, count, metadata)
    return false
end

--- true on success
function CustomBridge.RemoveItem(src, item, count, metadata, slot)
    return false
end

function CustomBridge.GetItemLabel(item)
    return item
end

-- ---------------------------------------------------------------------
--  Standalone (LibConfig.Framework = 'standalone') – optional
-- ---------------------------------------------------------------------

-- function CustomBridge.GetIdentifier(src) return GetPlayerIdentifierByType(src, 'license') end
-- function CustomBridge.GetName(src) return GetPlayerName(src) end
-- function CustomBridge.GetJob(src) return 'unemployed', 0, true end   -- name, grade, onDuty
-- function CustomBridge.GetGang(src) return nil, 0 end
-- function CustomBridge.CountPolice(jobs) return 0 end

-- Money type 'account' on standalone servers
-- function CustomBridge.GetAccount(src, name) return 0 end
-- function CustomBridge.RemoveAccount(src, name, amount, reason) return false end
-- function CustomBridge.AddAccount(src, name, amount, reason) return false end

-- ---------------------------------------------------------------------
--  Logs: every LAFL.Log(...) of every LAFL script ends up here.
--  resource = 'lafl_laundry', action = 'claim', data = { ... }
--  info = { name, identifier, source, time }
--  (Discord webhooks are set in config_server.lua)
-- ---------------------------------------------------------------------

function CustomBridge.Log(resource, src, action, data, info)
    -- Example:
    -- print(('[%s] %s (%d) %s %s'):format(resource, info.name, src, action, json.encode(data)))
end

-- ---------------------------------------------------------------------
--  Company accounts (LibConfig.Society = 'custom') – e.g. your own bank script
--  name = job / gang name ('mechanic')
-- ---------------------------------------------------------------------

-- function CustomBridge.GetSociety(name) return 0 end
-- function CustomBridge.AddSociety(name, amount, reason) return true end
-- function CustomBridge.RemoveSociety(name, amount, reason) return true end
