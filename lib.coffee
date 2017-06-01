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
    resp.result.fulfillment.speech is "" and not _.has resp.result.fulfillment, 'messages'

  apiai_resp_has_quick_replies: (resp) ->
    quick_replies = _.filter resp.result.fulfillment.messages, (message) ->
      message.type is 2
    if quick_replies.length then true else false

  apiai_resp_has_image: (api_response_data) ->
    _.findWhere api_response_data.result.fulfillment.messages, type: 3

  reply_with_image: (api_response_data) ->
    url = (_.sample (_.where api_response_data.result.fulfillment.messages, type: 3)).imageUrl
    attachment:
      type: 'image'
      payload:
        url: url

  reply_with_buttons: (api_response_data) ->
    # console.log api_response_data
    full_text = api_response_data.result.fulfillment.speech
    text = truncate_to_word full_text, 600
    quick_reply_message = _.findWhere api_response_data.result.fulfillment.messages, type: 2

    if quick_reply_message.title.match /options/i # real quick replies
      text: text
      quick_replies:
        _.map quick_reply_message.replies, (option) ->
          content_type: 'text'
          title: option
          payload: option
    else
      buttons =
        _.map quick_reply_message.title.split /; ?/, (text) ->
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
          payload: 'TELL_ME_MORE:' + full_text.substring text.length - 2
      attachment:
        type: 'template'
        payload:
          template_type: 'button'
          text: text
          buttons: buttons

  text_reply: (aa_speech) ->
    more_position = aa_speech.search /\[more\]/i

    if more_position is -1 and aa_speech.length < 600
      return aa_speech
    else if more_position isnt -1
      trimmedAnswer = aa_speech.substring 0, more_position
      residualAnswer = aa_speech.substring trimmedAnswer.length + 6, trimmedAnswer.length + 985
    else
      trimmedAnswer = truncate_to_word aa_speech, 600
      residualAnswer = aa_speech.substring trimmedAnswer.length - 2, trimmedAnswer.length + 985

    return attachment:
      type: 'template'
      payload:
        template_type: 'button'
        text: trimmedAnswer
        buttons: [
          type: 'postback'
          title: 'Tell me more'
          payload: 'TELL_ME_MORE:' + residualAnswer
        ]

  quick_replies_reply: (aa_message) ->
    text: aa_message.title
    quick_replies:
      _.map aa_message.replies, (qr) ->
        content_type: 'text'
        title: qr
        payload: qr

  image_reply: (aa_message) ->
    attachment:
      type: 'image'
      payload:
        url: aa_message.imageUrl

  space_out_and_delegate_messages: (bot, fb_message, aa_messages) ->
    i = 0

    # filter out bad api.ai duplicates
    aa_messages = _.uniq aa_messages, (m, key, speech) -> m.speech

    # messages with plain text first
    _.each (_.where aa_messages, type: 0), (m, i) ->
      setTimeout () ->
        bot.reply fb_message, lib.text_reply m.speech
      , i * 1000

    # then quick replies
    qr_message = _.findWhere aa_messages, type: 2
    if qr_message
      setTimeout () ->
        bot.reply fb_message, lib.quick_replies_reply qr_message
      , ++i * 1000 if qr_message

    # then an image picked at random
    image_message = _.sample _.where aa_messages, type: 3
    if image_message
      setTimeout () ->
        bot.reply fb_message, lib.image_reply image_message
      , ++i * 1000


lib = module.exports
