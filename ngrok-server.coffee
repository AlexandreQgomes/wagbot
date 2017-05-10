ngrok = require 'ngrok'

ngrok.connect
  authtoken: process.env.ngrok_authtoken
  subdomain: process.env.ngrok_subdomain
  addr: process.env.PORT or 3000
, (err, url) ->
  if err
    console.log err
    process.exit
  console.log "Your bot is available at #{url}/facebook/receive"
