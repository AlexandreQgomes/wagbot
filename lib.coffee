sqlite3 = require 'sqlite3'
  .verbose()
stats_db = new sqlite3.Database('wagbot.db')

module.exports =
  clean: (answer) ->
    # answer = answer
    #   .replace /&quot;|&#39;/g, "'"
    #   .replace /for example/gi, 'eg'
    if answer.length > 600
      answer = answer
        .substring 0, 600
        .concat '…'
    answer

  log_request: (message) ->
    stats_db.run "insert into requests (id, user, channel, request, timestamp) values (?,?,?,?,?)", [
      message.mid
      message.user
      message.channel
      message.match.input
      message.timestamp
    ]

  log_response: (message, data) ->
    stats_db.run "update requests set response = ?, score = ? where id = ?", [
      data.msg
      data.confidence
      message.mid
    ]

  log_no_kb_match: (message) ->
    stats_db.run "update requests set no_kb_match = 'true' where id = ?", [message.mid]

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
