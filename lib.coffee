_ = require 'underscore'
request = require 'request'

# thanks http://stackoverflow.com/a/5454303
truncate_to_word = (string, maxLength) ->
  if string.length > maxLength
    truncatedString = string.substring 0, maxLength
    truncatedString
      .substring 0, Math.min truncatedString.length, truncatedString.lastIndexOf ' '
      .concat ' …'
  else
    string

module.exports =
  apiai_no_match: (resp) ->
    resp.result.fulfillment.speech is ""

  apiai_resp_has_quick_replies: (resp) ->
    resp.result.fulfillment.messages and resp.result.fulfillment.messages.length > 1 and resp.result.fulfillment.messages[1].title.length > 0

  reply_with_buttons: (api_response_data) ->
    full_text = api_response_data.result.fulfillment.speech
    text = truncate_to_word full_text, 600
    quick_replies = api_response_data.result.fulfillment.messages[1].title.split /; ?/
    buttons =
      _.map quick_replies, (text) ->
        messenger_url = text.match /(.+) (https?:\/\/m\.me\/.+)/i
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
        payload: full_text.substring text.length - 2
    attachment:
      type: 'template'
      payload:
        template_type: 'button'
        text: text
        buttons: buttons

  clean: (answer) ->
    more_position = answer.search /\[more\]/i

    if more_position is -1 and answer.length < 600
      return answer
    else if more_position isnt -1
      trimmedAnswer = answer.substring 0, more_position
      residualAnswer = answer.substring trimmedAnswer.length + 6, trimmedAnswer.length + 998
    else
      trimmedAnswer = truncate_to_word answer, 600
      residualAnswer = answer.substring trimmedAnswer.length - 2, trimmedAnswer.length + 998

    return attachment:
      type: 'template'
      payload:
        template_type: 'button'
        text: trimmedAnswer
        buttons: [
          type: 'postback'
          title: 'Tell me more'
          payload: residualAnswer
        ]


lib = module.exports
