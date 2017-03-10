pg = require 'pg'
_ = require 'underscore'
request = require 'request'

stats_db = new pg.Client(process.env.DATABASE_URL or 'postgres://localhost:5432/wagbot';)
stats_db.connect()

# thanks http://stackoverflow.com/a/5454303
truncate_to_word = (string, maxLength) ->
  truncatedString = string.substring 0, maxLength
  truncatedString = truncatedString.substring 0, Math.min truncatedString.length, truncatedString.lastIndexOf ' '
  truncatedString.concat ' …'

module.exports =
  wit_converse_api: (question, api_error_func, api_success_func) ->
    uri = "https://api.wit.ai/converse?v=20160526&session_id=#{Math.random().toString(36).substring(2,11)}&q=#{question}"
    console.log "URI: #{uri}"
    request
      headers:
        'Authorization': "Bearer #{process.env.wit_client_token}"
        'Content-Type': 'application/json'
      uri: uri
      method: 'POST'
      , (err, res, body) ->
        if err then api_error_func
        else
          api_success_func body

  parse_quick_replies: (quickreplies_from_wit) ->
    buttons = _.map quickreplies_from_wit, (text) ->
      messenger_url = (text.match /http:\/\/m\.me\/\d+/i)[0]
      if messenger_url
        link_title = '💬 ' + (text.match /(.+) http:\/\/m\.me\/.+/i)[1]
        button =
          type: 'web_url'
          url: messenger_url
          title: link_title
      else
        button =
          type: 'postback'
          title: text
          payload: text
      button
    console.log buttons
    buttons

  clean: (answer) ->
    if answer.length > 600
      trimmedAnswer = truncate_to_word answer, 600
      return attachment:
        type: 'template'
        payload:
          template_type: 'button'
          text: trimmedAnswer
          buttons: [
            type: 'postback'
            title: 'Tell me more'
            payload: answer.substring trimmedAnswer.length - 2
          ]
    else
      return answer

  dont_know_message: () ->
    "attachment":
      "type": "template"
      "payload":
        "template_type": "button"
        "text": "Sorry, I don't know. But I get cleverer all the time, so you might have more luck if you ask me again in a day or two. Meantime, want to talk to a human?"
        "buttons": [
          "type": "phone_number"
          "title": "📞 Student Rights"
          "payload": "+64 800 499 488"
        ]


  log_request: (message) ->
    stats_db.query "insert into requests (id, \"user\", channel, request, timestamp) values ($1,$2,$3,$4,$5)", [
      message.mid
      message.user
      message.channel
      message.match.input
      message.timestamp
    ]

  log_response: (message, data) ->
    stats_db.query "update requests set response = $1, score = $2, intent = $3 where id = $4", [
      data.msg
      if data.entities.intent then data.entities.intent.confidence else null
      data.entities.intent.value
      message.mid
    ]

  log_no_kb_match: (message) ->
    stats_db.query "update requests set no_kb_match = 'true' where id = $1", [message.mid]

  formatUptime: (uptime) ->
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

lib = module.exports
