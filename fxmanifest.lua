fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'cc_multichar'
author 'charcreation'
description 'Cinematic character selector for FiveM (Qbox / QBCore / ESX) — click-to-select with framework-native handoffs'
version '2.0.0'

ui_page 'html/index.html'

files {
  'html/index.html',
}

shared_scripts {
  '@oxmysql/lib/MySQL.lua',
  'config/config.lua',
  'shared/log.lua',
  'shared/framework.lua',
}

client_scripts {
  'client/scene.lua',
  'client/ped_setup.lua',
  'client/hover.lua',
  'client/main.lua',
}

server_scripts {
  'server/database.lua',
  'server/slots.lua',
  'server/characters.lua',
  'server/instance.lua',
  'server/main.lua',
}
