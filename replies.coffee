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
  greeting: "Hi :), I'm wagbot, an experimental Community Law prototype. I'm still in training, but I can answer *some* questions about problems at school."

  get_started: "I can answer some questions about problems at schools. Try asking something like 'Can I be punished for not wearing the uniform?' or 'What happens to parents if their children wag school?' I'm still in training though, so there's heaps I don't know!"

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

  menu:
    [
      title:'Privacy policy'
      type: 'web_url'
      url: 'http://www.wclc.org.nz/privacy-confidentiality/'
    ]
