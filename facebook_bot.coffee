if not (process.env.page_token and process.env.verify_token and process.env.app_secret and process.env.apiai_client_token and process.env.DASHBOT_API_KEY)
  console.log 'Error: Specify page_token, verify_token, app_secret, apiai_client_token, and DASHBOT_API_KEY in environment'
  process.exit 1

Botkit = require 'botkit'
apiaibotkit = require 'api-ai-botkit'
_ = require 'underscore'
dashbot = require('dashbot')(process.env.DASHBOT_API_KEY).facebook
lib = require './lib'
replies = require './replies'
logging = require './logging'

apiai = apiaibotkit process.env.apiai_client_token

controller = Botkit.facebookbot
  debug: false
  log: false
  access_token: process.env.page_token
  verify_token: process.env.verify_token
  app_secret: process.env.app_secret
  validate_requests: true
  receive_via_postback: true

controller.middleware.receive.use dashbot.receive
controller.middleware.send.use dashbot.send

bot = controller.spawn()

controller.setupWebserver process.env.PORT or 3000, (err, webserver) ->
  controller.createWebhookEndpoints webserver, bot, () ->
    console.log 'ONLINE!'
    if process.env.ngrok_subdomain and process.env.ngrok_authtoken
      require ('./ngrok-server')


# controller.api.thread_settings.delete_greeting()
controller.api.thread_settings.greeting replies.greeting
controller.api.thread_settings.get_started replies.get_started
# controller.api.thread_settings.delete_menu()
controller.api.thread_settings.menu replies.menu

controller.hears ['(.*)'], 'message_received', (bot, message) ->
  if message.type is 'facebook_postback' and message.text.substring(0,13) == 'TELL_ME_MORE:'
    bot.reply message, lib.text_reply message.text.substring 13
  else
    bot.startTyping message, () ->
      logging.log_request message

      if message.match.input.match /uptime/i
        bot.reply message, replies.uptime()
      else
        apiai.process message, bot

apiai
  .all (fb_message, resp, bot) ->
    console.log "—API.AI RESPONSE————————————————"
    console.log resp
    console.log "—RESPONSE.result.fulfillment.messages————————————————"
    console.log resp.result.fulfillment.messages
    console.log "—————————————————"

    if lib.apiai_no_match resp
      bot.reply fb_message, replies.dont_know_try_calling
      logging.log_no_kb_match fb_message
    else
      lib.space_out_and_delegate_messages bot, fb_message, resp.result.fulfillment.messages
