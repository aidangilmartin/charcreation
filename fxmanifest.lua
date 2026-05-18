fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'cc_multichar'
author 'charcreation'
description 'Framework-agnostic (Qbox/QBCore) cinematic character selection'
version '0.1.0'

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/css/app.css',
  'html/js/app.js'
}

shared_scripts {
  '@oxmysql/lib/MySQL.lua',
  'config/*.lua',
  'shared/*.lua'
}

client_scripts {
  'client/*.lua'
}

server_scripts {
  'server/*.lua'
}
