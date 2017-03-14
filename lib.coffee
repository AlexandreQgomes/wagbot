pg = require 'pg'
_ = require 'underscore'
request = require 'request'
moment = require 'moment'

stats_db = new pg.Client(process.env.DATABASE_URL or 'postgres://localhost:5432/wagbot';)
stats_db.connect()

# thanks http://stackoverflow.com/a/5454303
truncate_to_word = (string, maxLength) ->
  truncatedString = string.substring 0, maxLength
  truncatedString = truncatedString.substring 0, Math.min truncatedString.length, truncatedString.lastIndexOf ' '
  truncatedString.concat ' …'

module.exports =
  dont_know_please_rephrase: "I'm sorry, I don't know. Perhaps try asking again with different words."

  dont_know_try_calling:
    attachment:
      type: 'template'
      payload:
        template_type: 'button'
        text: 'Sorry, I don\'t know. But I get cleverer all the time, so you might have more luck if you ask me again in a day or two. Meantime, want to talk to a human?'
        buttons: [
          type: 'phone_number'
          title: '📞 Student Rights'
          payload: '0800 499 488'
        ]

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
      messenger_url = text.match /(.+) (https?:\/\/m\.me\/\d+)/i
      phone_number = text.match /(.+) (0800.+)/
      if messenger_url
        button =
          type: 'web_url'
          url: messenger_url[2]
          title: '💬 ' + messenger_url[1]
      else if phone_number
        button =
          type: 'phone_number'
          title: '📞 ' + phone_number[1]
          payload: phone_number[2]
      else
        button =
          type: 'postback'
          title: text
          payload: text
      button
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

  reply_with_buttons: (api_response_data) ->
    attachment:
      type: 'template'
      payload:
        template_type: 'button'
        text: lib.clean api_response_data.msg
        buttons: lib.parse_quick_replies api_response_data.quickreplies

  wit_no_match: (data) ->
    _.isEmpty data.entities

  log_request: (controller, message) ->
    message_at = new Date(message.timestamp).toISOString()
    stats_db.query "insert into requests (id, \"user\", channel, request, message_at) values ($1,$2,$3,$4,$5)", [
      message.mid
      message.user
      message.channel
      message.match.input
      message_at
    ]

  log_response: (message, data) ->
    stats_db.query "update requests set response = $1, score = $2, intent = $3 where id = $4", [
      data.msg
      if data.entities.intent then data.entities.intent[0].confidence else null
      data.entities.intent[0].value
      message.mid
    ]

  log_no_kb_match: (controller, message) ->
    stats_db.query "update requests set no_kb_match = 'true' where id = $1", [message.mid]

  was_last_request_this_session_matched: (user_id, func) ->
    stats_db.query "select message_at from requests where \"user\" = $1 and no_kb_match is true and message_at is not null order by message_at desc limit 1", [user_id], (err, result) ->
      if result.rows[0]
        message_at = result.rows[0].message_at
        func moment(message_at) < moment().subtract(1, 'minute')
      else
        func true

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
