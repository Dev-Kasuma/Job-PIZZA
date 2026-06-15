fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'dev'
description 'Livreur de pizza'
version '1.0.0'


ui_page 'html/index.html'


shared_scripts {

    '@ox_lib/init.lua',
    '@es_extended/imports.lua',

    'config.lua'

}


client_scripts {

    'client.lua'

}


server_scripts {

    '@oxmysql/lib/MySQL.lua',

    'server.lua'

}


files {

    'html/index.html',
    'html/style.css',
    'html/app.js'

}


dependencies {

    'oxmysql',
    'es_extended',
    'ox_inventory',
    'ox_lib'

}