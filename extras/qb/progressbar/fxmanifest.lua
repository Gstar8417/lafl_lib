fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'progressbar'
author 'LAFL (G-Star)'
description 'Replacement for the QBCore progressbar – QBCore progress bar in the LAFL design (lafl_lib)'
version '1.0.0'

-- Replacement from lafl_lib/extras: same name, exports and events as the original,
-- everything is shown with lafl_lib. Start it AFTER lafl_lib.
-- Without lafl_lib it falls back to the plain GTA display.

client_script 'client.lua'
