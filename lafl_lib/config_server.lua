-- =====================================================================
--  LAFL LIB – server-only settings (never sent to players)
-- =====================================================================

LibConfig.Logs = {
    -- Every LAFL.Log(...) call is passed to CustomBridge.Log (custom/server.lua).
    -- Additionally it can be sent to a Discord webhook.
    discord  = false,
    webhook  = '',                -- default webhook for all scripts
    webhooks = {                  -- optional: own webhook per resource
        -- lafl_laundry = 'https://discord.com/api/webhooks/...',
    },
    username = 'LAFL Logs',
    color    = 15251530,          -- embed color (decimal), 15251530 = #e8b84a
    flagged  = true,              -- also send suspicious actions (LAFL.Security.Flag)
}
