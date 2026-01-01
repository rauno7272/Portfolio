fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Clappy'
description 'Send custom emails to players via lb-phone.'
version '1.0.0'

-- Shared configuration file
shared_scripts {
    '@ox_lib/init.lua', 
    '@oxmysql/lib/MySQL.lua', 
    'config.lua' 
}

-- Server-side script
server_script 'server/main.lua'

-- Client-side script
client_script 'client/main.lua'

-- Dependencies
dependencies {
    'ox_lib',
    'oxmysql',
    'lb-phone'
}
