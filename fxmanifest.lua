fx_version 'cerulean'
games { 'rdr3', 'gta5' }
lua54 'yes'

author 'SMJ-1337 & ardelan869'
description 'still thinking...'
version '1.0'

ui_page 'socket.html'
file 'socket.html'

shared_script 'shared/**/*'

client_script 'client/**/*'

server_scripts {
  'config/**/*',
  'server/**/*'
}
