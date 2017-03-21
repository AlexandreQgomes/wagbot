_ = require 'underscore'
request = require 'request'

# thanks http://stackoverflow.com/a/5454303
truncate_to_word = (string, maxLength) ->
  if string.length > maxLength
    truncatedString = string.substring 0, maxLength
    truncatedString.substring 0, Math.min truncatedString.length, truncatedString.lastIndexOf ' '
    truncatedString.concat ' …'
  else
    string

module.exports =
  apiai_no_match: (resp) ->
    resp.result.fulfillment.speech is ""

  wit_converse_api: (question, api_error_func, api_success_func) ->
    uri = "https://api.wit.ai/converse?v=20160526&session_id=#{Math.random().toString(36).substring(2,11)}&q=#{question}"
    console.log "URI: #{uri}"
    request
      headers:
        Authorization: "Bearer #{process.env.wit_client_token}"
        'Content-Type': 'application/json'
      uri: uri
      method: 'POST'
      , (err, res, body) ->
        if err then api_error_func
        else
          api_success_func body

  reply_with_buttons: (api_response_data) ->
    text = truncate_to_word api_response_data.msg, 600
    buttons =
      _.map api_response_data.quickreplies, (text) ->
        messenger_url = text.match /(.+) (https?:\/\/m\.me\/\d+)/i
        page_url = text.match /(.+) (https?:\/\/.+)/i
        phone_number = text.match /(.+) (0800.+)/
        if messenger_url
          type: 'web_url'
          url: messenger_url[2]
          title: '💬 ' + messenger_url[1]
        else if page_url
          type: 'web_url'
          url: page_url[2]
          title: '🔗 ' + page_url[1]
        else if phone_number
          type: 'phone_number'
          title: '📞 ' + phone_number[1]
          payload: phone_number[2]
        else
          type: 'postback'
          title: text
          payload: text
    if text.length > 600
      buttons.push
        type: 'postback'
        title: 'Tell me more'
        payload: api_response_data.msg.substring text.length - 2
    attachment:
      type: 'template'
      payload:
        template_type: 'button'
        text: text
        buttons: buttons

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
            payload: answer.substring trimmedAnswer.length - 2, trimmedAnswer.length + 998
          ]
    else
      return answer

  wit_no_match: (data) ->
    _.isEmpty data.entities

lib = module.exports
