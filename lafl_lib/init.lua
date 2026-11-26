-- =====================================================================
--  LAFL LIB – loader
--  Include in any resource:   shared_script '@lafl_lib/init.lua'
--  Creates the global LAFL object. Modules are loaded on first use
--  (LAFL.Inventory, LAFL.Money, ...) and run inside the calling resource,
--  so callbacks, targets and events belong to that resource.
-- =====================================================================

if LAFL then return end

local LIB  = 'lafl_lib'
local RES  = GetCurrentResourceName()
local SIDE = IsDuplicityVersion() and 'server' or 'client'
local IS_LIB = RES == LIB

if not IS_LIB then
    local state = GetResourceState(LIB)
    if state ~= 'started' and state ~= 'starting' then
        error(('^1[%s] lafl_lib is not started. Put "ensure lafl_lib" BEFORE this resource in your server.cfg.^7'):format(RES), 0)
    end
end

-- ---------------------------------------------------------------------
--  lafl_lib itself: accept common short names in config.lua
--  ('ox' = 'ox_lib', 'qbcore' = 'qb', ...) and warn about unknown values
-- ---------------------------------------------------------------------

if IS_LIB and type(LibConfig) == 'table' then
    local systems = {
        Framework = { valid = { esx = 1, qb = 1, standalone = 1 },
                      alias = { es_extended = 'esx', esx_legacy = 'esx', qbcore = 'qb', ['qb-core'] = 'qb', qbx = 'qb', qbx_core = 'qb', none = 'standalone' } },
        Inventory = { valid = { ox = 1, qb = 1, esx = 1, custom = 1 },
                      alias = { ox_inventory = 'ox', ['qb-inventory'] = 'qb', ['ps-inventory'] = 'qb', ['lj-inventory'] = 'qb', es_extended = 'esx' } },
        Target    = { valid = { ox = 1, qb = 1, textui = 1, text3d = 1 },
                      alias = { ox_target = 'ox', ['qb-target'] = 'qb', text = 'textui', ['text-ui'] = 'textui', none = 'textui', lafl = 'textui',
                                ['3d'] = 'text3d', ['text-3d'] = 'text3d', drawtext3d = 'text3d' } },
        Dispatch  = { valid = { lafl = 1, ['ps-dispatch'] = 1, cd_dispatch = 1, custom = 1 },
                      alias = { ps = 'ps-dispatch', ps_dispatch = 'ps-dispatch', cd = 'cd_dispatch', ['cd-dispatch'] = 'cd_dispatch', lafl_dispatch = 'lafl' } },
        Database  = { valid = { oxmysql = 1, none = 1 }, alias = { mysql = 'oxmysql', ox = 'oxmysql' } },
        Society   = { valid = { ['qb-banking'] = 1, ['renewed-banking'] = 1, esx = 1, custom = 1, none = 1 },
                      alias = { qb = 'qb-banking', qb_banking = 'qb-banking', qbx = 'renewed-banking', renewed = 'renewed-banking',
                                ['Renewed-Banking'] = 'renewed-banking', esx_addonaccount = 'esx', esx_society = 'esx', ['false'] = 'none' } },
    }
    local ui = { valid = { lafl = 1, ox_lib = 1, qb = 1, esx = 1, native = 1, custom = 1 },
                 alias = { ox = 'ox_lib', oxlib = 'ox_lib', ['ox-lib'] = 'ox_lib', qbcore = 'qb', ['qb-core'] = 'qb', es_extended = 'esx', gta = 'native', default = 'native', lafl_lib = 'lafl' } }
    systems.Notify, systems.Progress, systems.TextUI = ui, ui, ui
    systems.Text3D = { valid = { lafl = 1, textui = 1, original = 1 },
                       alias = { text = 'textui', ['text-ui'] = 'textui', native = 'original', gta = 'original', off = 'original', none = 'original', ['false'] = 'original', lafl_lib = 'lafl' } }

    for key, s in pairs(systems) do
        local value = LibConfig[key]
        if type(value) == 'string' then
            local v = value:lower()
            v = s.alias[v] or v
            if s.valid[v] then
                LibConfig[key] = v
            else
                local list = {}
                for name in pairs(s.valid) do list[#list + 1] = "'" .. name .. "'" end
                table.sort(list)
                print(('^1[lafl_lib] LibConfig.%s = \'%s\' is unknown. Use one of: %s^7'):format(key, value, table.concat(list, ', ')))
            end
        end
    end
end

LAFL = {
    name     = LIB,
    resource = RES,
    side     = SIDE,
    isServer = SIDE == 'server',
    Version  = GetResourceMetadata(LIB, 'version', 0) or '0.0.0',
}

-- ---------------------------------------------------------------------
--  Version check
-- ---------------------------------------------------------------------

local function parseVersion(v)
    local a, b, c = tostring(v or ''):match('(%d+)%.?(%d*)%.?(%d*)')
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

--- Compare two versions: -1 (a < b), 0 (equal), 1 (a > b)
function LAFL.CompareVersion(a, b)
    local a1, a2, a3 = parseVersion(a)
    local b1, b2, b3 = parseVersion(b)
    if a1 ~= b1 then return a1 < b1 and -1 or 1 end
    if a2 ~= b2 then return a2 < b2 and -1 or 1 end
    if a3 ~= b3 then return a3 < b3 and -1 or 1 end
    return 0
end

--- Stops the resource with a clear message if lafl_lib is too old
function LAFL.Require(minVersion)
    if LAFL.CompareVersion(LAFL.Version, minVersion) < 0 then
        error(('^1[%s] needs lafl_lib %s or newer (installed: %s). Download the latest lafl_lib.^7')
            :format(RES, minVersion, LAFL.Version), 0)
    end
    return true
end

-- ---------------------------------------------------------------------
--  Config of lafl_lib (lazy, so the export is only called when needed)
-- ---------------------------------------------------------------------

local libConfig

local function getConfig()
    if libConfig then return libConfig end
    if IS_LIB then
        libConfig = LibConfig
    else
        local ok, cfg = pcall(function() return exports[LIB]:GetConfig() end)
        if ok and cfg then
            libConfig = cfg
        else
            print(('^1[%s] Could not read the lafl_lib config. Is lafl_lib started before this resource?^7'):format(RES))
            return {}
        end
    end
    return libConfig
end

-- ---------------------------------------------------------------------
--  Small helpers available everywhere
-- ---------------------------------------------------------------------

--- Debug print, active with Config.Debug of the script or LibConfig.Debug
function LAFL.Debug(...)
    local scriptDebug = type(Config) == 'table' and Config.Debug
    if scriptDebug or getConfig().Debug then
        print(('^3[%s]^7'):format(RES), ...)
    end
end

--- Event name with resource prefix (prevents collisions)
function LAFL.Event(name)
    return RES .. ':' .. name
end

--- Unix time in seconds (same value on client and server)
function LAFL.Now()
    if SIDE == 'server' then return os.time() end
    return GetCloudTimeAsInt()
end

--- Current language: Config.Locale of the script, else lafl_lib default
function LAFL.Lang()
    return (type(Config) == 'table' and Config.Locale) or getConfig().Locale or 'en'
end

--- Call a function from lafl_lib/custom/*.lua. Returns found, ...results
function LAFL.Custom(name, ...)
    if IS_LIB then
        local fn = CustomBridge and CustomBridge[name]
        if type(fn) ~= 'function' then return false end
        return true, fn(...)
    end
    return exports[LIB]:CallCustom(name, ...)
end

--- Is the given function defined in lafl_lib/custom/*.lua?
function LAFL.HasCustom(name)
    if IS_LIB then return CustomBridge ~= nil and type(CustomBridge[name]) == 'function' end
    return exports[LIB]:HasCustom(name) == true
end

-- ---------------------------------------------------------------------
--  Module loader
-- ---------------------------------------------------------------------

local loading = {}

-- modules that exist (for a clear error message if a file is missing)
local KNOWN = {
    core = 'shared', format = 'shared', locale = 'shared', callback = 'side', player = 'side', inventory = 'side',
    notify = 'side', dispatch = 'side', minigame = 'side', money = 'server', police = 'server', db = 'server',
    security = 'server', log = 'server', progress = 'client', textui = 'client', anim = 'client', target = 'client', world = 'client',
}

local function loadFile(path)
    local code = LoadResourceFile(LIB, path)
    if not code then return nil end
    local fn, err = load(code, ('@@%s/%s'):format(LIB, path), 't', _ENV)
    if not fn then error(('[lafl_lib] %s: %s'):format(path, err), 0) end
    return fn
end

local function loadModule(self, key)
    if type(key) ~= 'string' or loading[key] then return nil end
    local name = key:lower()
    loading[key] = true

    local fn = loadFile(('modules/%s/%s.lua'):format(name, SIDE)) or loadFile(('modules/%s/shared.lua'):format(name))
    if not fn then
        loading[key] = nil
        if KNOWN[name] then
            print(('^1[%s] lafl_lib module "%s" could not be loaded (modules/%s/%s.lua). Is the lafl_lib folder complete and named exactly "lafl_lib"?^7')
                :format(RES, key, name, KNOWN[name] == 'shared' and 'shared' or SIDE))
        end
        return nil
    end

    local ok, mod = pcall(fn)
    loading[key] = nil
    if not ok then
        print(('^1[%s] lafl_lib module "%s" failed: %s^7'):format(RES, key, tostring(mod)))
        return nil
    end

    rawset(self, key, mod)
    return mod
end

setmetatable(LAFL, {
    __index = function(self, key)
        if key == 'Config' then return getConfig() end
        return loadModule(self, key)
    end,
})
