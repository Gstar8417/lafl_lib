-- =====================================================================
--  LAFL.Minigame (client)
--
--  local ok = LAFL.Minigame.Start('thermite', { difficulty = 'hard', rounds = 3 })
--  local ok = LAFL.Minigame.Lockpick({ difficulty = 'easy' })       -- shortcut
--
--  Games: lockpick, skillcheck, hack, thermite, safe, drill, wires, keypad
--  For rewards use LAFL.Minigame.Await on the SERVER (checked with a token).
-- =====================================================================

local Minigame = {}

Minigame.Games = { 'lockpick', 'skillcheck', 'hack', 'thermite', 'safe', 'drill', 'wires', 'keypad' }

local valid = {}
for _, g in ipairs(Minigame.Games) do valid[g] = true end

function Minigame.Start(game, opts)
    return exports[LAFL.name]:Minigame(game, opts or {}) == true
end

function Minigame.Active()
    return exports[LAFL.name]:MinigameActive() == true
end

function Minigame.Stop()
    exports[LAFL.name]:StopMinigame()
end

return setmetatable(Minigame, {
    __index = function(_, key)
        local game = type(key) == 'string' and key:lower()
        if game and valid[game] then
            return function(opts) return Minigame.Start(game, opts) end
        end
    end,
})
