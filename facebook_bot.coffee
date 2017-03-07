if not (process.env.page_token and process.env.verify_token and process.env.app_secret and process.env.wit_client_token)
  console.log 'Error: Specify page_token, verify_token, app_secret, wit_client_token in environment'
  process.exit 1

Botkit = require 'botkit'
os = require 'os'
localtunnel = require 'localtunnel'
request = require 'request'
_ = require 'underscore'
lib = require './lib'


controller = Botkit.facebookbot
  debug: false
  log: true
  access_token: process.env.page_token
  verify_token: process.env.verify_token
  app_secret: process.env.app_secret
  validate_requests: true           # // Refuse any requests that don't come from FB on your receive webhook, must provide FB_APP_SECRET in environment variables

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


controller.api.thread_settings.greeting "Hi :), I'm wagbot, an experimental Community Law project. I'm pretty dumb, but I know the answers to some questions you might have about problems at school."

controller.hears ['(.*)'], 'message_received', (bot, message) ->
  bot.startTyping message, () ->
    lib.log_request message

    question = message.match.input

    if question.match /uptime|identify yourself|who are you|what is your name|what's your name/i
      bot.reply message, ":) I'm wagbot. I've been running for #{lib.formatUptime process.uptime()} on #{os.hostname()}"
    else
      request
        headers:
          'Authorization': "Bearer #{process.env.wit_client_token}"
          'Content-Type': 'application/json'
        uri: "https://api.wit.ai/converse?v=20160526&session_id=#{Math.random().toString(36).substring(2,11)}&q=#{question}",
        method: 'POST'
        , (err, res, body) ->
          if err
            bot.reply message, "Sorry, something went wrong :'( — error # #{err}"
          else
            console.log "Body: #{body}"
            data = JSON.parse(body)
            if data.type is 'stop'
              bot.reply message,
                "attachment":
                  "type": "template"
                  "payload":
                    "template_type": "button"
                    "text": "Sorry, I've got no idea. Want to talk to someone with some clues?"
                    "buttons": [
                      "type": "phone_number"
                      "title": "📞 Call Community Law"
                      "payload": "+64 4 499 2928"
                    ]
              lib.log_no_kb_match message

            else
              if data.quickreplies
                quick_replies = _.map data.quickreplies, (val) ->
                  content_type: 'text'
                  title: val
                  payload: 'empty'

                bot.reply message,
                  text: lib.clean data.msg
                  quick_replies: quick_replies
              else
                bot.reply message, lib.clean data.msg
                console.log "Message:"
                console.log message

              lib.log_response message, data

# this isn't doing anything :(
controller.on 'facebook_postback', (bot, message) ->
  console.log bot, message
  bot.reply message, 'Great Choice!!!! (' + message.payload + ')'


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
