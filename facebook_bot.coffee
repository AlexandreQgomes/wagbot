if not (process.env.page_token and process.env.verify_token and process.env.app_secret and process.env.wit_client_token)
  console.log 'Error: Specify page_token, verify_token, app_secret, wit_client_token in environment'
  process.exit 1

Botkit = require 'botkit'
os = require 'os'
localtunnel = require 'localtunnel'
lib = require './lib'
_ = require 'underscore'
moment = require 'moment'
botkitStoragePostgres = require 'botkit-storage-postgres'


controller = Botkit.facebookbot
  debug: false
  log: true
  access_token: process.env.page_token
  verify_token: process.env.verify_token
  app_secret: process.env.app_secret
  validate_requests: true           # // Refuse any requests that don't come from FB on your receive webhook, must provide FB_APP_SECRET in environment variables
  storage: botkitStoragePostgres
    host: process.env.BOTKIT_STORAGE_POSTGRES_HOST
    user: process.env.BOTKIT_STORAGE_POSTGRES_USER
    password: process.env.BOTKIT_STORAGE_POSTGRES_PASSWORD
    database: process.env.BOTKIT_STORAGE_POSTGRES_DATABASE

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
    lib.log_request message

    question = message.match.input

    if question.match /uptime|identify yourself|who are you|what is your name|what's your name/i
      bot.reply message, ":) I'm wagbot. I've been running for #{lib.formatUptime process.uptime()} on #{os.hostname()}"
    else
      lib.wit_converse_api question, () ->
        bot.reply message, "Sorry, something went wrong :'( — error # #{err}"
      , (body) ->
        console.log "Body: #{body}"
        data = JSON.parse(body)

        if lib.wit_no_match data
          controller.storage.users.get message.user, (err, user_data) ->
            if user_data and user_data.last_no_match
              if moment(user_data.last_no_match) < moment().subtract(10, 'seconds') # no_match in earlier session
                bot.reply message, lib.dont_know_please_rephrase
              else                                                                  # no_match this session
                bot.reply message, lib.dont_know_try_calling
            else
              bot.reply message, lib.dont_know_please_rephrase                      # never a no_match

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
