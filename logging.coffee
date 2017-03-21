pg = require 'pg'
moment = require 'moment'

db = new pg.Client(process.env.DATABASE_URL or 'postgres://localhost:5432/wagbot';)
db.connect (err) ->
  if err
    console.log "Postgres connection error: #{err}"
    process.exit 1

module.exports =
  log_request: (message) ->
    message_at = new Date(message.timestamp).toISOString()
    db.query "insert into requests (id, \"user\", channel, request, message_at) values ($1,$2,$3,$4,$5);"
    , [
      message.mid
      message.user
      message.channel
      message.match.input
      message_at
    ]
    , (err, result) -> if err then console.log err

    db.query "insert into users (id, requests) values ($1, 1) on conflict (id) do update set requests = users.requests + 1"
    , [message.user]
    , (err, result) -> if err then console.log err

  log_response: (message, data) ->
    db.query "update requests set response = $1, score = $2, intent = $3 where id = $4", [
      data.msg
      if data.entities.intent then data.entities.intent[0].confidence else null
      data.entities.intent[0].value
      message.mid
    ]

  log_no_kb_match: (message) ->
    db.query "update requests set no_kb_match = 'true' where id = $1", [message.mid]

    last_no_match_at = new Date(message.timestamp).toISOString()
    db.query "insert into users (id, last_no_match_at) values ($1, $2) on conflict (id) do update set last_no_match_at = $2", [
      message.user
      last_no_match_at
    ], (err, result) -> if err then console.log err

  was_last_request_this_session_matched: (user_id, func) ->
    db.query "select last_no_match_at from users where id = $1 limit 1", [user_id], (err, result) ->
      if err then console.log err
      else if result.rows[0]
        message_at = result.rows[0].message_at
        func moment(message_at) < moment().subtract(1, 'minute')
      else
        func true

  how_many_questions: (user_id, func) ->
    db.query "select requests from users where id = $1 limit 1", [user_id], (err, result) ->
      if err then console.log err
      else if result.rows[0]
        func result.rows[0].requests
      else
        func 0
