if not (process.env.page_token and process.env.verify_token and process.env.app_secret)
  console.log 'Error: Specify page_token, verify_token, app_secret in environment'
  process.exit 1

if not (process.env.kb_host and process.env.kb_id and process.env.subscription_key)
  console.log 'Error: specify knowledgebase credentials in environment'
  process.exit 1

Botkit = require 'botkit'
os = require 'os'
commandLineArgs = require 'command-line-args'
localtunnel = require 'localtunnel'
request = require 'request'

ops = commandLineArgs [
  name: 'lt'
  alias: 'l'
  args: 1
  description: 'Use localtunnel.me to make your bot available on the web.'
  type: Boolean
  defaultValue: false
,
  name: 'ltsubdomain'
  alias: 's'
  args: 1,
  description: 'Custom subdomain for the localtunnel.me URL. This option can only be used together with --lt.'
  type: String
  defaultValue: null
]

if ops.lt is false and ops.ltsubdomain isnt null
  console.log "error: --ltsubdomain can only be used together with --lt."
  process.exit()


controller = Botkit.facebookbot
  debug: true
  log: true
  access_token: process.env.page_token
  verify_token: process.env.verify_token
  app_secret: process.env.app_secret
  validate_requests: true           # // Refuse any requests that don't come from FB on your receive webhook, must provide FB_APP_SECRET in environment variables

bot = controller.spawn()

controller.setupWebserver process.env.port or 3000, (err, webserver) ->
  controller.createWebhookEndpoints webserver, bot, () ->
    console.log 'ONLINE!'
    if ops.lt
      tunnel = localtunnel process.env.port or 3000, subdomain: ops.ltsubdomain, (err, tunnel) ->
        if err
          console.log err
          process.exit()
        console.log "Your bot is available on the web at the following URL: #{tunnel.url}/facebook/receive"

      tunnel.on 'close', () ->
        console.log "Your bot is no longer available on the web at the localtunnnel.me URL."
        process.exit()

controller.api.thread_settings.greeting 'Hello! I\'m a Botkit bot!'
controller.api.thread_settings.get_started 'sample_get_started_payload'
controller.api.thread_settings.menu [
  "type":"postback"
  "title":"Hello"
  "payload":"hello"
,
  "type":"postback"
  "title":"Help"
  "payload":"help"
,
  "type":"web_url"
  "title":"Botkit Docs"
  "url":"https://github.com/howdyai/botkit/blob/master/readme-facebook.md"
]

clean = (answer) ->
  answer = answer
    .replace /&quot;|&#39;/g, "'"
    .replace /for example/gi, 'eg'
  if answer.length > 600
    answer = answer
      .substring 0, 600
      .concat '…'
  answer

controller.hears ['(.*)'], 'message_received', (bot, message) ->
  question = message.match[1]

  if question.match /hi|hello|howdy/i
    bot.reply message, "Hi there, I'm wagbot. I'm pretty dumb, but I know the answers to some questions you might have about problems at school."
  else if question.match /uptime|identify yourself|who are you|what is your name|what's your name/i
    bot.reply message, ":) I'm wagbot. I've been running for #{formatUptime process.uptime()} on #{os.hostname()}"
  else
    request
      headers:
        'Ocp-Apim-Subscription-Key': process.env.subscription_key
        'Content-Type': 'application/json'
      uri: "#{process.env.kb_host}/knowledgebases/#{process.env.kb_id}/generateAnswer",
      json:
        question: question
      method: 'POST'
      , (err, res, body) ->
        if err
          bot.reply message, "Sorry, summit went wrong-o: #{err}"
        else
          if body.answer is "No good match found in the KB"
            bot.reply message, "Sorry, I've got no idea. Want to talk to someone at Community Law?"
          else
            bot.reply message, clean body.answer

#
#
# controller.hears ['quick'], 'message_received', (bot, message) ->
#   bot.reply message,
#     text: 'Hey! This message has some quick replies attached.'
#     quick_replies: [
#       "content_type": "text"
#       "title": "Yes"
#       "payload": "yes"
#     ,
#       "content_type": "text"
#       "title": "No"
#       "payload": "no"
#     ]
#

controller.hears ['silent push reply'], 'message_received', (bot, message) ->
  bot.reply message,
    text: "This message will have a push notification on a mobile phone, but no sound notification"
    notification_type: "SILENT_PUSH"

controller.hears ['no push'], 'message_received', (bot, message) ->
  bot.reply message,
    text: "This message will not have any push notification on a mobile phone"
    notification_type: "NO_PUSH"

controller.hears ['structured'], 'message_received', (bot, message) ->
  bot.startConversation message, (err, convo) ->
    convo.ask
      attachment:
        'type': 'template'
        'payload':
          'template_type': 'generic'
          'elements': [
            'title': 'Classic White T-Shirt'
            'image_url': 'http://petersapparel.parseapp.com/img/item100-thumb.png'
            'subtitle': 'Soft white cotton t-shirt is back in style'
            'buttons': [
              'type': 'web_url'
              'url': 'https://petersapparel.parseapp.com/view_item?item_id=100'
              'title': 'View Item'
            ,
              'type': 'web_url'
              'url': 'https://petersapparel.parseapp.com/buy_item?item_id=100'
              'title': 'Buy Item'
            ,
              'type': 'postback',
              'title': 'Bookmark Item',
              'payload': 'White T-Shirt'
            ]
          ,
            'title': 'Classic Grey T-Shirt'
            'image_url': 'http://petersapparel.parseapp.com/img/item101-thumb.png'
            'subtitle': 'Soft gray cotton t-shirt is back in style'
            'buttons': [
              'type': 'web_url'
              'url': 'https://petersapparel.parseapp.com/view_item?item_id=101'
              'title': 'View Item'
            ,
              'type': 'web_url'
              'url': 'https://petersapparel.parseapp.com/buy_item?item_id=101'
              'title': 'Buy Item'
            ,
              'type': 'postback'
              'title': 'Bookmark Item'
              'payload': 'Grey T-Shirt'
            ]
          ]
      , (response, convo) ->
        # // whoa, I got the postback payload as a response to my convo.ask!
        convo.next()

controller.on 'facebook_postback', (bot, message) ->
  # // console.log(bot, message);
  bot.reply message, "Great Choice!!!! (#{message.payload})"

controller.hears ['call me (.*)', 'my name is (.*)'], 'message_received', (bot, message) ->
  name = message.match[1]
  controller.storage.users.get message.user, (err, user) ->
    if not user
      user =
        id: message.user
    user.name = name
    controller.storage.users.save user, (err, id) ->
      bot.reply message, "Got it. I will call you #{user.name} from now on."

controller.hears ['what is my name', 'who am i'], 'message_received', (bot, message) ->
  controller.storage.users.get message.user, (err, user) ->
    if user and user.name
      bot.reply message, "Your name is #{user.name}"
    else
      bot.startConversation message, (err, convo) ->
        if not err
          convo.say 'I do not know your name yet!'
          convo.ask 'What should I call you?', (response, convo) ->
            convo.ask "You want me to call you `#{response.text}`?", [
              pattern: 'yes'
              callback: (response, convo) ->
                # // since no further messages are queued after this,
                # // the conversation will end naturally with status == 'completed'
                convo.next()
            ,
              pattern: 'no'
              callback: (response, convo) ->
                # // stop the conversation. this will cause it to end with status == 'stopped'
                convo.stop()
            ,
              default: true
              callback: (response, convo) ->
                convo.repeat()
                convo.next()
            ]

            convo.next()
          , 'key': 'nickname' # // store the results in a field called nickname

          convo.on 'end', (convo) ->
            if convo.status is 'completed'
              bot.reply message, 'OK! I will update my dossier...'

              controller.storage.users.get message.user, (err, user) ->
                if not user
                  user =
                    id: message.user
                user.name = convo.extractResponse 'nickname'
                controller.storage.users.save user, (err, id) ->
                  bot.reply message, "Got it. I will call you #{user.name} from now on."
            else
              # // this happens if the conversation ended prematurely for some reason
              bot.reply message, 'OK, nevermind!'

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

controller.on 'message_received', (bot, message) ->
  bot.reply message, 'Try: `what is my name` or `structured` or `call me captain`'
  false

formatUptime = (uptime) ->
  unit = 'second'
  if uptime > 60
    uptime = uptime / 60
    unit = 'minute'
  if uptime > 60
    uptime = uptime / 60
    unit = 'hour'

  uptime = Math.round(uptime)

  if uptime isnt 1
    unit = unit + 's'

  uptime = uptime + ' ' + unit
  uptime
