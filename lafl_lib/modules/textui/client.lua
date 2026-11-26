-- =====================================================================
--  LAFL.TextUI (client)
--  LAFL.TextUI.Show('Waschmaschine benutzen', { key = 'E', icon = '🧺' })
--  LAFL.TextUI.Hide()
-- =====================================================================

local TextUI = {}

function TextUI.Show(text, opts)
    exports[LAFL.name]:ShowTextUI(text, opts or {})
end

function TextUI.Hide()
    exports[LAFL.name]:HideTextUI()
end

function TextUI.IsOpen()
    return exports[LAFL.name]:IsTextUIOpen() == true
end

return TextUI
