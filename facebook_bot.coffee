if not (process.env.page_token and process.env.verify_token and process.env.app_secret and process.env.wit_client_token)
  console.log 'Error: Specify page_token, verify_token, app_secret, wit_client_token in environment'
  process.exit 1

Botkit = require 'botkit'
ngrok = require 'ngrok'
_ = require 'underscore'

lib = require './lib'
replies = require './replies'
logging = require './logging'

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


controller.api.thread_settings.greeting "Hi :), I'm wagbot, an experimental Community Law project. I'm pretty dumb, but I can answer some questions about problems at school."
controller.api.thread_settings.get_started "Try asking something like 'Can I be punished for not wearing the uniform?' or 'What happens to parents if their children wag school?'"
controller.api.thread_settings.delete_menu()


controller.hears ['(.*)'], 'message_received', (bot, message) ->
  bot.startTyping message, () ->
    logging.log_request message

    question = message.match.input

    if question.match /uptime|identify yourself|who are you|what is your name|what's your name/i
      bot.reply message, replies.uptime()
    else
      lib.wit_converse_api question
      , () ->
        bot.reply message, "Sorry, something went wrong :'( — error # #{err}"
      , (body) ->
        console.log "Body: #{body}"
        data = JSON.parse(body)

        if lib.wit_no_match data
          logging.was_last_request_this_session_matched message.user, (matched) ->
            if matched
              bot.reply message, replies.dont_know_please_rephrase
            else
              logging.how_many_questions message.user, (n) ->
                bot.reply message, replies.dont_know_training n
            logging.log_no_kb_match message

        else
          if data.quickreplies
            bot.reply message, lib.reply_with_buttons data
          else
            bot.reply message, lib.clean data.msg

          logging.log_response message, data

controller.on 'facebook_postback', (bot, message) ->
  console.log "Facebook postback: "
  console.log message
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
