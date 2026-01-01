fx_version 'cerulean'
game 'gta5'
author 'Clappy'
description 'Clappy Race - Target Point Racing Lobby Script (React UI - Buildless)'
version '2.1.2' -- Updated version for separated buildless React UI
lua54 'yes'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/App.jsx',
    'history.json'
}

shared_script 'shared/config.lua'

client_script 'client/client.lua'
server_script 'server/server.lua'

dependencies {
    'qb-core',
    'ox_target'
}

