if not (process.env.page_token and process.env.verify_token and process.env.app_secret and process.env.wit_client_token)
  console.log 'Error: Specify page_token, verify_token, app_secret, wit_client_token in environment'
  process.exit 1

Botkit = require 'botkit'
os = require 'os'
localtunnel = require 'localtunnel'
lib = require './lib'
_ = require 'underscore'
moment = require 'moment'

controller = Botkit.facebookbot
  debug: false
  log: true
  access_token: process.env.page_token
  verify_token: process.env.verify_token
  app_secret: process.env.app_secret
  validate_requests: true

bot = controller.spawn()

controller.setupWebserver process.env.PORT or 3000, (err, webserver) ->
  controller.createWebhookEndpoints webserver, bot, () ->
    console.log 'ONLINE!'
    if process.env.ltsubdomain
      tunnel_handler = (err, tunnel) ->
        if err
          console.log err
          process.exit
        console.log "Your bot is available at #{tunnel.url}/facebook/receive"

      tunnel = localtunnel process.env.PORT or 3000, subdomain: process.env.ltsubdomain, tunnel_handler

      tunnel.on 'close', () ->
        console.log "Your bot is no longer available on the web #{tunnel.url}"
        process.exit()

      tunnel.on 'error', (err) ->
        console.log err
        console.log "Attempting to restart…"

        setTimeout () ->
          tunnel.close()
          tunnel = localtunnel process.env.PORT or 3000, subdomain: process.env.ltsubdomain, tunnel_handler
        , 3000


controller.api.thread_settings.greeting "Hi :), I'm wagbot, an experimental Community Law project. I'm pretty dumb, but I can answer some questions about problems at school."
controller.api.thread_settings.get_started "Try asking something like 'Can I be punished for not wearing the uniform?' or 'What happens to parents if their children wag school?'"
controller.api.thread_settings.delete_menu()


controller.hears ['(.*)'], 'message_received', (bot, message) ->
  bot.startTyping message, () ->
    lib.log_request controller, message

    question = message.match.input

    if question.match /uptime|identify yourself|who are you|what is your name|what's your name/i
      bot.reply message, ":) I'm wagbot. I've been running for #{lib.formatUptime process.uptime()} on #{os.hostname()}"
    else
      lib.wit_converse_api question
      , () ->
        bot.reply message, "Sorry, something went wrong :'( — error # #{err}"
      , (body) ->
        console.log "Body: #{body}"
        data = JSON.parse(body)

        if lib.wit_no_match data
          lib.was_last_request_this_session_matched message.user, (matched) ->
            if matched
              bot.reply message, lib.dont_know_please_rephrase
            else
              bot.reply message, lib.dont_know_try_calling
            lib.log_no_kb_match controller, message

        else
          if data.quickreplies
            bot.reply message, lib.reply_with_buttons data
          else
            bot.reply message, lib.clean data.msg

          lib.log_response message, data

controller.on 'facebook_postback', (bot, message) ->
  console.log "Facebook postback: " + message
  bot.reply message, lib.clean message.payload


controller.hears ['shutdown'], 'message_received', (bot, message) ->
  bot.startConversation message, (err, convo) ->
    convo.ask 'Are you sure you want me to shutdown?', [
      pattern: bot.utterances.yes
      callback: (response, convo) ->
        convo.say 'Bye!'
        convo.next()
        setTimeout () ->
          process.exit()
        , 3000
    ,
      pattern: bot.utterances.no
      default: true
      callback: (response, convo) ->
        convo.say '*Phew!*'
        convo.next()
    ]
