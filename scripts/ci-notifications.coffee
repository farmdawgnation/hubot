# Take in notifications about Continuous integration and broadcast
# information into the Main Flow on Flowdock.
querystring = require('querystring')

module.exports = (robot) ->
  robot.router.get "/hubot/ci-notification", (req, res) ->
    console.log(require('url').parse(req.url).query)
    query = querystring.parse(require('url').parse(req.url).query)

    user = {}
    user.room = query.room if query.room
    user.type = query.type if query.type
    user.flow = query.flow if query.flow

    user.name = "Siri"

    console.log("User information parsed.")

    projectName = query.projectName
    buildStatus = query.buildStatus
    commit = query.commit
    commitAuthor = query.commitAuthor
    branch = query.branch

    console.log("Message built.")

    message = ""

    if buildStatus == "passing"
      message = "The build of " + branch + " for commit " + commit + " by " + commitAuthor + " has passed all tests."
    else
      message = commitAuthor + " broke the build for " + branch + " with commit " + commit

    if branch == "master"
      message += " This code has been deployed to production. @everyone #release"

    console.log("Sending message to room.")

    robot.adapter.bot.flows (flows) ->
      console.log(flows)
      flowids = flow.id for flow in flows
      robot.send({ flow: flowids[0] }, "test")
      res.end "OK"
