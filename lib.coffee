pg = require 'pg'

stats_db = new pg.Client(process.env.DATABASE_URL or 'postgres://localhost:5432/wagbot';)
stats_db.connect()

module.exports =
  clean: (answer) ->
    # answer = answer
    #   .replace /&quot;|&#39;/g, "'"
    #   .replace /for example/gi, 'eg'
    if answer.length > 600
      answer = answer
        .substring 0, 600
        .concat '…'
      return answer
      # return text: answer, quick_replies: [
      #     content_type: 'text'
      #     title: 'Tell me more'
      #     payload: answer.substring 600
      #   ]
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
    stats_db.query "update requests set response = $1, score = $2 where id = $3", [
      data.msg
      data.confidence
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
