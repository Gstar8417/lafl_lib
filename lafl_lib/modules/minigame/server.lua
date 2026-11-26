-- =====================================================================
--  LAFL.Minigame (server) – the safe way for rewards
--
--  local ok = LAFL.Minigame.Await(src, 'hack', { difficulty = 'medium', rounds = 3 })
--  if ok then giveLoot(src) end
--
--  The server starts the game with a one-time token, only accepts the answer of
--  this player for this token, and rejects wins that are impossibly fast.
-- =====================================================================

local Minigame = {}

Minigame.Games = { 'lockpick', 'skillcheck', 'hack', 'thermite', 'safe', 'drill', 'wires', 'keypad' }

local valid = {}
for _, g in ipairs(Minigame.Games) do valid[g] = true end

function Minigame.Await(src, game, opts)
    return exports[LAFL.name]:MinigameAwait(src, game, opts or {}) == true
end

function Minigame.Active(src)
    return exports[LAFL.name]:MinigameActive(src) == true
end

return setmetatable(Minigame, {
    __index = function(_, key)
        local game = type(key) == 'string' and key:lower()
        if game and valid[game] then
            return function(src, opts) return Minigame.Await(src, game, opts) end
        end
    end,
})
