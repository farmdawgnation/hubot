# Take in notification emails and broadcast their contents into
# the flow.
module.exports = (robot) ->
  robot.router.get "/hubot/notification-email", (req, res) ->
    res.end()

  robot.router.post "/hubot/notification-email", (req, res) ->
    for event in JSON.parse(req.body.mandrill_events)
      user = {}
      user.flow = event.msg.subject
      user.name = "Siri"

      if event.msg.text
        message = event.msg.text.replace(/\n+$/, "")
        robot.send(user, message)

    res.end()
