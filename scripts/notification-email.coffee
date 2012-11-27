# Take in notification emails and broadcast their contents into
# the flow.
querystring = require('querystring')

module.exports = (robot) ->
  robot.router.get "/hubot/notification-email", (req, res) ->
    query = querystring.parse(require('url').parse(req.url).query)
    mandrill_events = req.body.mandrill_events

    for event in mandrill_events
      user = {}
      user.flow = event.msg.subject
      user.name = "Siri"

      if event.msg.text
        message = event.msg.text.replace(/\n+$/, "")
        robot.send(user, message)

    res.end()
