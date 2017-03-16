os = require 'os'

formatUptime = (uptime) ->
  unit = 'second'
  if uptime > 60
    uptime = uptime / 60
    unit = 'minute'
  if uptime > 60
    uptime = uptime / 60
    unit = 'hour'
  uptime = Math.round(uptime)
  if uptime isnt 1 then unit += 's'
  uptime + ' ' + unit

module.exports =
  dont_know_please_rephrase: "I'm sorry, I don't know. Perhaps try asking again with different words."

  dont_know_training: (n) ->
    if n < 2
      "Sorry, I don't know. But while I'm in training it's really helpful to ask me as many different questions as you can, so I can be taught the answers."
    else
      "Sorry, I don't know. Do keep asking though, so I can be taught more answers. You've asked #{n} questions — thanks!"

  dont_know_try_calling:
    attachment:
      type: 'template'
      payload:
        template_type: 'button'
        text: 'Sorry, I don\'t know. But I get a little bit cleverer each day, so you could try again later. Meantime, want to talk to a human?'
        buttons: [
          type: 'phone_number'
          title: '📞 Student Rights'
          payload: '0800 499 488'
        ]

  uptime: () ->
    "I'm Wagbot. I've been running for #{formatUptime process.uptime()} on #{os.hostname()}"
