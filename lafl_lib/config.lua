-- =====================================================================
--  LAFL LIB – central settings for ALL LAFL scripts
--  Everything is set manually here, nothing is auto-detected.
--  The single scripts only keep their own settings (+ accent color).
--  Server-only settings (Discord webhooks) are in config_server.lua.
-- =====================================================================

LibConfig = {}

LibConfig.Debug  = false      -- true = console output of lafl_lib + visible target zones
LibConfig.Locale = 'de'       -- default language: 'de' | 'en' (a script can override it with Config.Locale)

-- ---------------------------------------------------------------------
--  Systems
-- ---------------------------------------------------------------------
LibConfig.Framework = 'qb'          -- 'esx' | 'qb' | 'standalone'
LibConfig.Inventory = 'ox'          -- 'ox'  | 'qb' | 'esx' | 'custom'
LibConfig.Target    = 'ox'          -- 'ox'  | 'qb' | 'textui' / 'text3d' (no target script: "[E] ..." at the screen edge / as label in the world)
LibConfig.Notify    = 'lafl'        -- 'lafl' | 'ox_lib' | 'qb' | 'esx' | 'native' | 'custom'
LibConfig.Progress  = 'lafl'        -- 'lafl' | 'ox_lib' | 'qb' | 'esx' | 'native' | 'custom'
LibConfig.TextUI    = 'lafl'        -- 'lafl' | 'ox_lib' | 'qb' | 'esx' | 'native' | 'custom'
LibConfig.Text3D    = 'lafl'        -- 3D text of other scripts: 'lafl' (LAFL design in the world) | 'textui' (LAFL text UI) | 'original'
LibConfig.Dispatch  = 'ps-dispatch' -- 'lafl' | 'ps-dispatch' | 'cd_dispatch' | 'custom'
LibConfig.Database  = 'oxmysql'     -- 'oxmysql' | 'none'
LibConfig.Society   = 'qb-banking'  -- company accounts: 'qb-banking' (QBCore) | 'renewed-banking' (Qbox) | 'esx' (esx_addonaccount) | 'custom' | 'none'
LibConfig.SocietyPrefix = 'society_' -- ESX only: account name = prefix .. job ('society_mechanic')
-- 'custom' = add your own functions in lafl_lib/custom/client.lua or custom/server.lua
-- Short names work too ('ox' = 'ox_lib', 'qbcore' = 'qb', 'ox_inventory' = 'ox', 'ps' = 'ps-dispatch' ...).
-- An unknown value is reported in the server / F8 console.

-- ---------------------------------------------------------------------
--  General
-- ---------------------------------------------------------------------
LibConfig.Currency          = '$'
LibConfig.InteractDistance  = 2.0     -- reach for ox_target / qb-target / textui
LibConfig.MaxActionDistance = 6.0     -- default for LAFL.Security.InRange (server anti-cheat)
LibConfig.CallbackTimeout   = 10000   -- ms until a callback without answer returns nil

-- Item images. nil = automatic for the selected inventory:
--   ox -> nui://ox_inventory/web/images/%s.png    qb -> nui://qb-inventory/html/images/%s.png
-- false = no images (emojis only).
LibConfig.ImagePath = nil

-- ---------------------------------------------------------------------
--  Police (LAFL.Police.Count / IsPolice)
-- ---------------------------------------------------------------------
LibConfig.PoliceJobs   = { 'police', 'sheriff' }
LibConfig.PoliceOnDuty = true          -- QBCore: only count officers on duty

-- ---------------------------------------------------------------------
--  LAFL design (notify, progress, text UI, minigames)
--  The menus of the single scripts use their own accent (Config.UI).
-- ---------------------------------------------------------------------
LibConfig.UI = {
    accent     = '#e8b84a',     -- LAFL gold
    accentText = '#231a05',
}

LibConfig.NotifySettings = {
    position   = 'center-right', -- 'top-right' | 'center-right' | 'bottom-right' | 'top-left' | 'center-left' | 'bottom-left' | 'top' | 'bottom'
    duration   = 5000,           -- ms, default
    maxVisible = 5,
    sound      = true,           -- short sound for 'lafl' notifications
}

LibConfig.ProgressSettings = {
    position  = 'bottom',        -- 'bottom' | 'center'
    cancelKey = 73,              -- X
}

-- Only for LibConfig.Target = 'textui' / 'text3d'
LibConfig.TextTargetSettings = {
    key             = 38,      -- E (control id)
    keyLabel        = 'E',     -- shown in the text UI
    vehicleDistance = 3.0,     -- reach for vehicle interactions
    scanInterval    = 200,     -- ms between searches for the nearest interaction
}

LibConfig.TextUISettings = {
    position = 'center-left',    -- 'center-left' | 'center-right' | 'top' | 'bottom'
}

-- 3D text (qbx.drawText3d / QBCore.Functions.DrawText3D / ESX.Game.Utils.DrawText3D – see README)
LibConfig.Text3DSettings = {
    scale       = 1.0,           -- size of the 3D labels
    maxDistance = 20.0,          -- hidden when the camera is further away (m)
}

-- ---------------------------------------------------------------------
--  Minigames
-- ---------------------------------------------------------------------
LibConfig.Minigames = {
    sounds = true,
    -- Server check for LAFL.Minigame.Await: a win faster than this (ms per round)
    -- is rejected and logged as suspicious.
    minTime = {
        lockpick   = 700,
        skillcheck = 200,
        hack       = 1500,
        thermite   = 1500,
        safe       = 1200,
        drill      = 2500,
        wires      = 500,
        keypad     = 1500,
    },
    timeoutBuffer = 15,          -- seconds added to the game time before the server gives up
}

-- ---------------------------------------------------------------------
--  Texts of lafl_lib itself (progress, text UI, minigames)
--  Missing keys fall back to English.
-- ---------------------------------------------------------------------
LibConfig.Locales = {
    de = {
        cancel          = 'Abbrechen',
        working         = 'Wird ausgeführt...',
        coords_copied   = 'Koordinaten kopiert',
        mg_abort        = 'Abbrechen',
        mg_success      = 'Geschafft',
        mg_fail         = 'Fehlgeschlagen',
        mg_timeout      = 'Zeit abgelaufen',
        mg_round        = 'Runde',
        mg_mistakes     = 'Fehler',

        lockpick_title  = 'Schloss knacken',
        lockpick_sub    = 'Finde die richtige Stelle für den Dietrich',
        lockpick_hint   = 'Maus / A D: Dietrich bewegen · Leertaste halten: drehen',
        lockpick_picks  = 'Dietriche',
        lockpick_broke  = 'Dietrich abgebrochen',

        skillcheck_title = 'Geschick',
        skillcheck_sub   = 'Drücke die Taste, wenn der Zeiger im Feld ist',
        skillcheck_hint  = 'Angezeigte Taste im richtigen Moment drücken (E auch per Linksklick)',

        hack_title      = 'Hacken',
        hack_sub        = 'Merke dir die Zahlen und klicke sie der Reihe nach',
        hack_hint       = 'Merken · dann 1, 2, 3 … anklicken',
        hack_memorize   = 'Merken',
        hack_input      = 'Eingabe',

        thermite_title  = 'Thermit',
        thermite_sub    = 'Merke dir die markierten Felder',
        thermite_hint   = 'Merken · dann alle Felder anklicken',

        safe_title      = 'Tresor',
        safe_sub        = 'Dreh in die angezeigte Richtung und hör auf das Klicken',
        safe_hint       = 'A D / Mausrad: drehen · Shift: schneller · Leertaste: Zahl setzen',
        safe_signal     = 'Signal',
        safe_right      = 'Nach rechts drehen',
        safe_left       = 'Nach links drehen',
        safe_wrong_dir  = 'Falsche Richtung',

        drill_title     = 'Bohren',
        drill_sub       = 'Halte den Druck im grünen Bereich, ohne zu überhitzen',
        drill_hint      = 'Leertaste / Maus halten: Druck · loslassen: abkühlen',
        drill_pressure  = 'Druck',
        drill_heat      = 'Hitze',
        drill_broke     = 'Bohrer überhitzt',

        wires_title     = 'Kabel',
        wires_sub       = 'Trenne das Kabel, das zum ⚡ führt',
        wires_hint      = 'Kabel vom ⚡ zurückverfolgen · links an der Schere schneiden',

        keypad_title    = 'Tastenfeld',
        keypad_sub      = 'Finde den Code',
        keypad_hint     = 'Ziffern eingeben · Enter: prüfen',
        keypad_hint_fb  = 'Grün = richtig · Gelb = falsche Stelle · Grau = nicht im Code',
        keypad_tries    = 'Versuche',
    },

    en = {
        cancel          = 'Cancel',
        working         = 'Working...',
        coords_copied   = 'Coordinates copied',
        mg_abort        = 'Cancel',
        mg_success      = 'Success',
        mg_fail         = 'Failed',
        mg_timeout      = 'Time is up',
        mg_round        = 'Round',
        mg_mistakes     = 'Mistakes',

        lockpick_title  = 'Lockpick',
        lockpick_sub    = 'Find the right spot for the pick',
        lockpick_hint   = 'Mouse / A D: move pick · hold Space: turn',
        lockpick_picks  = 'Picks',
        lockpick_broke  = 'Pick broke',

        skillcheck_title = 'Skill check',
        skillcheck_sub   = 'Press the key when the pointer is in the zone',
        skillcheck_hint  = 'Press the shown key at the right moment (E also with left click)',

        hack_title      = 'Hack',
        hack_sub        = 'Remember the numbers and click them in order',
        hack_hint       = 'Remember · then click 1, 2, 3 …',
        hack_memorize   = 'Remember',
        hack_input      = 'Input',

        thermite_title  = 'Thermite',
        thermite_sub    = 'Remember the marked tiles',
        thermite_hint   = 'Remember · then click all tiles',

        safe_title      = 'Safe',
        safe_sub        = 'Turn in the shown direction and listen for the click',
        safe_hint       = 'A D / wheel: turn · Shift: faster · Space: set number',
        safe_signal     = 'Signal',
        safe_right      = 'Turn right',
        safe_left       = 'Turn left',
        safe_wrong_dir  = 'Wrong direction',

        drill_title     = 'Drill',
        drill_sub       = 'Keep the pressure in the green zone without overheating',
        drill_hint      = 'Hold Space / mouse: pressure · release: cool down',
        drill_pressure  = 'Pressure',
        drill_heat      = 'Heat',
        drill_broke     = 'Drill overheated',

        wires_title     = 'Wires',
        wires_sub       = 'Cut the wire that leads to ⚡',
        wires_hint      = 'Trace the wire back from ⚡ · cut it at the scissors on the left',

        keypad_title    = 'Keypad',
        keypad_sub      = 'Find the code',
        keypad_hint     = 'Enter digits · Enter: check',
        keypad_hint_fb  = 'Green = correct · Yellow = wrong spot · Grey = not in code',
        keypad_tries    = 'Tries',
    },
}
