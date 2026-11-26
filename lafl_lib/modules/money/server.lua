-- =====================================================================
--  LAFL.Money (server) – one API for all kinds of money
--
--  def = { type = 'item',        name = 'black_money' }            1 item = 1 $
--        { type = 'account',     name = 'bank' }                   QB money type / ESX account
--        { type = 'markedbills', name = 'markedbills', worthKey = 'worth' }   bags with a value (qb / ox)
--  Shortcuts: LAFL.Money.Get(src, 'bank') = account, LAFL.Money.Get(src, 'item:money') = item
-- =====================================================================

local Money = {}
local Core = LAFL.Core

local function normalize(def)
    if type(def) == 'table' then return def end
    if type(def) == 'string' then
        local t, n = def:match('^(%w+):(.+)$')
        if t then return { type = t, name = n } end
        return { type = 'account', name = def }
    end
    error('LAFL.Money: invalid money definition', 2)
end

-- ---------------------------------------------------------------------
--  Accounts
-- ---------------------------------------------------------------------

local function getAccount(src, name)
    local fw = LAFL.Config.Framework
    if fw == 'esx' then
        local xPlayer = Core.ESX().GetPlayerFromId(src)
        local acc = xPlayer and xPlayer.getAccount(name)
        return acc and acc.money or 0
    elseif fw == 'qb' then
        local p = Core.QB().Functions.GetPlayer(src)
        return p and p.PlayerData.money[name] or 0
    end
    local _, amount = LAFL.Custom('GetAccount', src, name)
    return tonumber(amount) or 0
end

local function removeAccount(src, name, amount, reason)
    local fw = LAFL.Config.Framework
    if getAccount(src, name) < amount then return false end
    if fw == 'esx' then
        local xPlayer = Core.ESX().GetPlayerFromId(src)
        if not xPlayer then return false end
        xPlayer.removeAccountMoney(name, amount, reason)
        return true
    elseif fw == 'qb' then
        local p = Core.QB().Functions.GetPlayer(src)
        if not p then return false end
        return p.Functions.RemoveMoney(name, amount, reason) and true or false
    end
    local _, ok = LAFL.Custom('RemoveAccount', src, name, amount, reason)
    return ok == true
end

local function addAccount(src, name, amount, reason)
    local fw = LAFL.Config.Framework
    if fw == 'esx' then
        local xPlayer = Core.ESX().GetPlayerFromId(src)
        if not xPlayer then return false end
        xPlayer.addAccountMoney(name, amount, reason)
        return true
    elseif fw == 'qb' then
        local p = Core.QB().Functions.GetPlayer(src)
        if not p then return false end
        return p.Functions.AddMoney(name, amount, reason) and true or false
    end
    local _, ok = LAFL.Custom('AddAccount', src, name, amount, reason)
    return ok == true
end

-- ---------------------------------------------------------------------
--  Marked bills (bags with a value in the metadata)
-- ---------------------------------------------------------------------

local function bagWorth(def) return def.worthKey or 'worth' end

--- Bags of the player, smallest first: { slot, count, worth, metadata }
local function billSlots(src, def)
    local key, list = bagWorth(def), {}
    for _, s in ipairs(LAFL.Inventory.Slots(src, def.name)) do
        local worth = math.floor(tonumber(s.metadata and s.metadata[key]) or 0)
        if worth > 0 then list[#list + 1] = { slot = s.slot, count = s.count, worth = worth, metadata = s.metadata } end
    end
    table.sort(list, function(a, b) return a.worth < b.worth end)
    return list
end

local function addBag(src, def, worth)
    return LAFL.Inventory.Add(src, def.name, 1, { [bagWorth(def)] = worth })
end

local function totalBills(src, def)
    local total = 0
    for _, s in ipairs(billSlots(src, def)) do total = total + s.count * s.worth end
    return total
end

--- Take bags worth at least `amount`, change comes back as a new bag
local function takeBills(src, def, amount)
    if totalBills(src, def) < amount then return false end
    local need = amount
    for _, s in ipairs(billSlots(src, def)) do
        if need <= 0 then break end
        local take = math.min(s.count, math.ceil(need / s.worth))
        if LAFL.Inventory.Remove(src, def.name, take, s.metadata, s.slot) then need = need - take * s.worth end
    end
    if need > 0 then
        local taken = amount - need
        if taken > 0 then addBag(src, def, taken) end   -- give back what was taken
        return false
    end
    if need < 0 then addBag(src, def, -need) end       -- change
    return true
end

-- ---------------------------------------------------------------------
--  Public API
-- ---------------------------------------------------------------------

function Money.Get(src, def)
    def = normalize(def)
    if def.type == 'account' then return getAccount(src, def.name) end
    if def.type == 'markedbills' then return totalBills(src, def) end
    return LAFL.Inventory.Count(src, def.name)
end

function Money.Has(src, def, amount)
    return Money.Get(src, def) >= amount
end

--- reason: shown in QB / ESX money logs (default: resource name)
function Money.Remove(src, def, amount, reason)
    def = normalize(def)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    reason = reason or LAFL.resource
    if def.type == 'account' then return removeAccount(src, def.name, amount, reason) end
    if def.type == 'markedbills' then return takeBills(src, def, amount) end
    return LAFL.Inventory.Remove(src, def.name, amount)
end

function Money.Add(src, def, amount, reason)
    def = normalize(def)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    reason = reason or LAFL.resource
    if def.type == 'account' then return addAccount(src, def.name, amount, reason) end
    if def.type == 'markedbills' then return addBag(src, def, amount) end
    return LAFL.Inventory.Add(src, def.name, amount)
end

-- ---------------------------------------------------------------------
--  Company / society accounts (LibConfig.Society)
--  name = job or gang name ('mechanic'). ESX: LibConfig.SocietyPrefix .. name
-- ---------------------------------------------------------------------

local function society() return LAFL.Config.Society or 'none' end

local function esxAccount(name)
    local acc
    TriggerEvent('esx_addonaccount:getSharedAccount', (LAFL.Config.SocietyPrefix or 'society_') .. name, function(a) acc = a end)
    return acc
end

--- Money of a company account (0 if unknown)
function Money.GetSociety(name)
    local s = society()
    local ok, v = pcall(function()
        if s == 'qb-banking' then return exports['qb-banking']:GetAccountBalance(name) end
        if s == 'renewed-banking' then return exports['Renewed-Banking']:getAccountMoney(name) end
        if s == 'esx' then local a = esxAccount(name) return a and a.money end
        if s == 'custom' then local _, m = LAFL.Custom('GetSociety', name) return m end
    end)
    return ok and tonumber(v) or 0
end

--- Pay into a company account. true on success
function Money.AddSociety(name, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if not name then return false end
    reason = reason or LAFL.resource
    local s = society()
    local ok, res = pcall(function()
        if s == 'qb-banking' then return exports['qb-banking']:AddMoney(name, amount, reason) end
        if s == 'renewed-banking' then return exports['Renewed-Banking']:addAccountMoney(name, amount) end
        if s == 'esx' then local a = esxAccount(name) if not a then return false end a.addMoney(amount) return true end
        if s == 'custom' then local _, r = LAFL.Custom('AddSociety', name, amount, reason) return r end
        return false
    end)
    if not ok then print(('^1[%s] Society account "%s" (%s): %s^7'):format(LAFL.resource, tostring(name), s, tostring(res))) end
    return ok and res ~= false and res ~= nil
end

--- Take money from a company account. true on success
function Money.RemoveSociety(name, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if not name or Money.GetSociety(name) < amount then return false end
    reason = reason or LAFL.resource
    local s = society()
    local ok, res = pcall(function()
        if s == 'qb-banking' then return exports['qb-banking']:RemoveMoney(name, amount, reason) end
        if s == 'renewed-banking' then return exports['Renewed-Banking']:removeAccountMoney(name, amount) end
        if s == 'esx' then local a = esxAccount(name) if not a then return false end a.removeMoney(amount) return true end
        if s == 'custom' then local _, r = LAFL.Custom('RemoveSociety', name, amount, reason) return r end
        return false
    end)
    return ok and res ~= false and res ~= nil
end

function Money.CanReceive(src, def, amount)
    def = normalize(def)
    if (amount or 0) <= 0 or def.type == 'account' then return true end
    if def.type == 'markedbills' then return LAFL.Inventory.CanCarry(src, def.name, 1) end
    return LAFL.Inventory.CanCarry(src, def.name, amount)
end

return Money
