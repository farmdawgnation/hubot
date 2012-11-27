# Take in notification emails and broadcast their contents into
# the flow.
querystring = require('querystring')

module.exports = (robot) ->
  robot.router.get "/hubot/notification-email", (req, res) ->
    query = querystring.parse(require('url').parse(req.url).query)

    user = {}
    user.flow = query.subject # use the subject to target the room
    user.name = "Siri"

    if query.text
      message = query.text.replace(/\n+$/, "")
      robot.send(user, message)

    res.end("OK")
