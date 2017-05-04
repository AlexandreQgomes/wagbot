if not (process.env.page_token and process.env.verify_token and process.env.app_secret and process.env.apiai_client_token and process.env.DASHBOT_API_KEY)
  console.log 'Error: Specify page_token, verify_token, app_secret, apiai_client_token, and DASHBOT_API_KEY in environment'
  process.exit 1

Botkit = require 'botkit'
apiaibotkit = require 'api-ai-botkit'
ngrok = require 'ngrok'
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

controller.middleware.receive.use dashbot.receive
controller.middleware.send.use dashbot.send

bot = controller.spawn()

controller.setupWebserver process.env.PORT or 3000, (err, webserver) ->
  controller.createWebhookEndpoints webserver, bot, () ->
    console.log 'ONLINE!'
    if process.env.ngrok_subdomain and process.env.ngrok_authtoken
      ngrok.connect
        authtoken: process.env.ngrok_authtoken
        subdomain: process.env.ngrok_subdomain
        addr: process.env.PORT or 3000
      , (err, url) ->
        if err
          console.log err
          process.exit
        console.log "Your bot is available at #{url}/facebook/receive"


controller.api.thread_settings.greeting replies.greeting
controller.api.thread_settings.get_started replies.get_started
controller.api.thread_settings.delete_menu()


controller.hears ['(.*)'], 'message_received', (bot, message) ->
  bot.startTyping message, () ->
    logging.log_request message

    if message.match.input.match /uptime/i
      bot.reply message, replies.uptime()
    else
      apiai.process message, bot

# after a message is not matched; then 3 minutes later, once a day,
# send a message "want me to get someone to follow up?" (just send 'followupuser')
# then it will need to email somone (https://nodemailer.com/)

apiai
  .all (message, resp, bot) ->
    console.log JSON.stringify resp, null, 4

    if lib.apiai_no_match resp
      logging.was_a_request_not_matched_last_minute message.user, (matched) ->
        if matched
          bot.reply message, replies.dont_know_please_rephrase
        else
          bot.reply message, replies.dont_know_try_calling
        logging.log_no_kb_match message

    else
      if lib.apiai_resp_has_quick_replies resp
        bot.reply message, lib.reply_with_buttons resp
      else if lib.apiai_resp_has_image resp
        if resp.result.fulfillment.speech
          bot.reply message, lib.prep_reply resp.result.fulfillment.speech
        bot.reply message, lib.reply_with_image resp
      else
        bot.startConversation message, (response, convo) ->     # https://github.com/howdyai/botkit/issues/543#issue-194748804
          _.each resp.result.fulfillment.messages, (m) ->
            if m.type is 0 and m.speech
              convo.say lib.prep_reply m.speech


        logging.log_response message, resp


controller.on 'facebook_postback', (bot, message) ->
  console.log "Facebook postback: "
  console.log message
  bot.reply message, lib.prep_reply message.payload
