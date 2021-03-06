# Take in notifications about Continuous integration and broadcast
# information into the Main Flow on Flowdock.
querystring = require('querystring')

module.exports = (robot) ->
  robot.router.get "/hubot/ci-notification", (req, res) ->
    query = querystring.parse(require('url').parse(req.url).query)

    user = {}
    user.room = query.room if query.room
    user.type = query.type if query.type
    user.flow = query.flow if query.flow

    user.name = "Siri"

    projectName = query.projectName
    buildStatus = query.buildStatus
    commit = query.commit
    commitAuthor = query.commitAuthor
    branch = query.branch

    message = ""

    if buildStatus == "passing"
      message = "The build of " + branch + " for commit " + commit + " by " + commitAuthor + " has passed all tests."
    else
      message = commitAuthor + " broke the build for " + branch + " with commit " + commit + "."

    if branch == "master" && buildStatus == "passing"
      message += " This code has been deployed to production. #release"

    robot.send(user, message)
    res.end("OK")
