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
      if message.mid then message.mid else 0
      message.user
      message.channel
      message.match.input
      message_at
    ]
    , (err, result) -> if err then console.log err

    db.query "insert into users (id, requests) values ($1, 1) on conflict (id) do update set requests = users.requests + 1"
    , [message.user]
    , (err, result) -> if err then console.log err

  log_response: (message, resp) ->
    db.query "update requests set response = $1, score = $2, intent = $3 where id = $4", [
      resp.result.fulfillment.speech
      resp.result.score
      resp.result.metadata.intentName
      message.mid
    ]

  log_no_kb_match: (message) ->
    db.query "update requests set no_kb_match = 'true' where id = $1", [message.mid]

    last_no_match_at = new Date(message.timestamp).toISOString()
    db.query "insert into users (id, last_no_match_at) values ($1, $2) on conflict (id) do update set last_no_match_at = $2", [
      message.user
      last_no_match_at
    ], (err, result) -> if err then console.log err

  was_a_request_not_matched_last_minute: (user_id, func) ->
    db.query "select last_no_match_at < now() - '1 minute'::interval no_match_last_min from users where id = $1 limit 1", [user_id], (err, result) ->
      if err then console.log err
      func result.rows[0] and result.rows[0].no_match_last_min

  how_many_questions: (user_id, func) ->
    db.query "select requests from users where id = $1 limit 1", [user_id], (err, result) ->
      if err then console.log err
      else if result.rows[0]
        func result.rows[0].requests
      else
        func 0
