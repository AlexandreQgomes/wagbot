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

buttons_prep = (button_text) ->
  button_text
    .split /; ?/
    .map (b) ->
      messenger_url = b.match /(.+) (https?:\/\/m\.me\/.+)/i
      page_url = b.match /(.+) (https?:\/\/.+)/i
      phone_number = b.match /(.+) (0800.+)/
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

text_splitter = (text) ->
  more_position = text.search /\[more\]/i
  if more_position is -1 and text.length < 600
    reply_text = text
  else if more_position isnt -1
    reply_text = text.substring 0, more_position
    overflow = text.substring reply_text.length + 6, reply_text.length + 985
  else if text.length > 600
    reply_text = truncate_to_word text, 600
    overflow = text.substring reply_text.length - 2, reply_text.length + 985
  reply_text: reply_text
  overflow: overflow

quick_replies_reply = (aa_message) ->
  text: aa_message.title
  quick_replies:
    _.map aa_message.replies, (qr) ->
      content_type: 'text'
      title: qr
      payload: qr

image_reply = (aa_message) ->
  attachment:
    type: 'image'
    payload:
      url: aa_message.imageUrl

module.exports =
  apiai_no_match: (resp) ->
    resp.result.fulfillment.speech is "" and not _.has resp.result.fulfillment, 'messages'

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
    if qr_message and qr_message.replies.length > 0 # skipping malformed (old) buttons
      setTimeout () ->
        bot.reply fb_message, quick_replies_reply qr_message
      , ++i * 1000 if qr_message

    # then an image picked at random
    image_message = _.sample _.where aa_messages, type: 3
    if image_message
      setTimeout () ->
        bot.reply fb_message, image_reply image_message
      , ++i * 1000

  text_reply: (aa_speech) ->
    split_text = text_splitter aa_speech
    button_string = split_text.reply_text.match /\[(.*(0800|http).*)\]/i
    if not button_string and not split_text.overflow
      return aa_speech

    buttons = []
    if button_string
      buttons = buttons_prep button_string[1]
      reply_text = split_text.reply_text
        .replace /\[(.*(0800|http).*)\]/i, ''
        .trim()
    if split_text.overflow
      reply_text = split_text.reply_text
      buttons.push
        type: 'postback'
        title: 'Tell me more'
        payload: 'TELL_ME_MORE:' + split_text.overflow
    attachment:
      type: 'template'
      payload:
        template_type: 'button'
        text: reply_text
        buttons: buttons

lib = module.exports
