pg = require 'pg'

stats_db = new pg.Client(process.env.DATABASE_URL or 'postgres://localhost:5432/wagbot';)
stats_db.connect()

# thanks http://stackoverflow.com/a/5454303
truncate_to_word = (string, maxLength) ->
  truncatedString = string.substring 0, maxLength
  truncatedString = truncatedString.substring 0, Math.min truncatedString.length, truncatedString.lastIndexOf ' ' # re-trim if we are in the middle of a word
  truncatedString.concat ' …'

module.exports =
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
