fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'cc_multichar'
author 'charcreation'
description 'Cinematic multi-character selector for FiveM (Qbox / QBCore / ESX)'
version '1.0.0'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/assets/**/*',
}

shared_scripts {
  '@oxmysql/lib/MySQL.lua',
  'config/logging.lua',
  'config/core.lua',
  'config/scenarios.lua',
  'config/spawn.lua',
  'config/ui.lua',
  'config/security.lua',
  'shared/framework.lua',
  'shared/log.lua',
}

client_scripts {
  'client/scene.lua',
  'client/scenarios.lua',
  'client/hover.lua',
  'client/spawn.lua',
  'client/overlay.lua',
  'client/main.lua',
}

server_scripts {
  'server/database.lua',
  'server/slots.lua',
  'server/characters.lua',
  'server/main.lua',
}
