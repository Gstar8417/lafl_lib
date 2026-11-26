fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'lafl_lib'
author 'LAFL (Gstar8417)'
description 'Shared library for all LAFL scripts: bridge (ESX / QB / standalone), money, database, security, notify, progress, text UI, dispatch and minigames'
version '1.0.7'

-- Usage in another resource (fxmanifest.lua):
--   dependency 'lafl_lib'
--   shared_script '@lafl_lib/init.lua'

ui_page 'web/index.html'

files {
    'init.lua',
    -- modules that are loaded on the client (listed one by one on purpose)
    'modules/anim/client.lua',
    'modules/callback/client.lua',
    'modules/core/shared.lua',
    'modules/dispatch/client.lua',
    'modules/format/shared.lua',
    'modules/inventory/client.lua',
    'modules/locale/shared.lua',
    'modules/minigame/client.lua',
    'modules/notify/client.lua',
    'modules/player/client.lua',
    'modules/progress/client.lua',
    'modules/target/client.lua',
    'modules/textui/client.lua',
    'modules/world/client.lua',
    'web/index.html',
    'web/*.css',
    'web/*.js',
    'web/games/*.js',
    'web/fonts/*.woff2',
}

shared_scripts {
    'config.lua',
    'init.lua',
}

client_scripts {
    'custom/client.lua',
    'core/client.lua',
    'core/textui_target.lua',
}

server_scripts {
    'config_server.lua',
    'custom/server.lua',
    'core/server.lua',
}
