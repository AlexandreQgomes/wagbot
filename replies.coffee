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

  if uptime isnt 1
    unit = unit + 's'

  uptime = uptime + ' ' + unit
  uptime

module.exports =
  dont_know_please_rephrase: "I'm sorry, I don't know. Perhaps try asking again with different words."

  dont_know_try_calling:
    attachment:
      type: 'template'
      payload:
        template_type: 'button'
        text: 'Sorry, I don\'t know. But I get cleverer all the time, so you might have more luck if you ask me again in a day or two. Meantime, want to talk to a human?'
        buttons: [
          type: 'phone_number'
          title: '📞 Student Rights'
          payload: '0800 499 488'
        ]

  uptime: ":) I'm wagbot. I've been running for #{formatUptime process.uptime()} on #{os.hostname()}"
