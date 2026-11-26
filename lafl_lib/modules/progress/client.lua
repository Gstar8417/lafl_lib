-- =====================================================================
--  LAFL.Progress (client) – returns true (finished) / false (cancelled)
--
--  local ok = LAFL.Progress({
--      duration = 5000, label = 'Bohren...',
--      anim = { dict = '...', clip = '...', flag = 1 } | { scenario = 'WORLD_HUMAN_WELDING' },
--      prop = { model = 'prop_tool_drill', bone = 57005, pos = vec3(...), rot = vec3(...) },
--      canCancel = true, disable = { move = true, car = true, combat = true },
--  })
-- =====================================================================

local Progress = {}

function Progress.Start(opts)
    return exports[LAFL.name]:Progress(opts or {}) == true
end

function Progress.Active()
    return exports[LAFL.name]:ProgressActive() == true
end

function Progress.Cancel()
    exports[LAFL.name]:CancelProgress()
end

return setmetatable(Progress, {
    __call = function(_, opts) return Progress.Start(opts) end,
})
