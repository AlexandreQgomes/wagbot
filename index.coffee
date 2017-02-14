# # POST /knowledgebases/f2aa6f8f-2dda-458f-978a-9adefd33ae95/generateAnswer
# # Host:
# #
# # Content-Type: application/json
# # {"question":"hi"};
#
# request = require 'request'
#
host = 'https://westus.api.cognitive.microsoft.com/qnamaker/v1.0'
kb_id = 'f2aa6f8f-2dda-458f-978a-9adefd33ae95'
subscription_key = '6ae213e5a2664bff800ffb82712ab39a'

request = require 'request'

request
  headers:
    'Ocp-Apim-Subscription-Key': subscription_key
    'Content-Type': 'application/json'
  uri: "#{host}/knowledgebases/#{kb_id}/generateAnswer",
  json:
    question: 'Do I have to go to school?',
  method: 'POST'
  , (err, res, body) ->
    if !err
      console.log body
    else
      console.log "Error: #{err}"


# FB page: https://www.facebook.com/Pas-test-159252184578799/
# FB page access token:  EAAFQ7fKKYT8BAKQGhDURAUK5OgLZCyeiIbZBXCvWRBB1MVaritXrbK2rKQcrhMis0Bi88O591yZCrWSe6E9Y2IFiUvc0aOrQRa36kiK2WHZAP7sFRYXi0Yl7d4RpO0lpP29tyZBUB1ObR6ZBrhlWhLv3ZCkCReEzrTNtZCZAy7obVWgZDZD
# verify token: bwokentwoken56779
