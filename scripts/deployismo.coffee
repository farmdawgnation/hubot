# Description:
#   An interface for our Hubot to help manage a GitHub-like deployment process by interacting
#   with the GitHub API. The assumption with this script is that you have some build system
#   updating the CI build status of commits in pull requests, much like Jenkins does with the
#   GitHub Pull Request Builder plugin.
#
#   This bot interface is one part of our deploy strategy at Kevy.
#
# Dependencies:
#   "github": ">= 0.1.7"
#
# Configuration:
#   DEPLOYISMO_USERNAME: The username deployismo should use to authenticate.
#   DEPLOYISMO_PASSWORD: The password deployismo should use to authenticate.
#   DEPLOYISMO_REPO_USER: The repository user.
#   DEPLOYISMO_REPO_REPO: The repo name.
#   DEPLOYISMO_DEPLOY_COMMAND: The deploy command to execute on the shell.
#   DEPLOYISMO_ROLLBACK_COMMAND: The rollback command to execute on the shell.
#   DEPLOYISMO_STATUS_COMMAND: The status command to execute on the shell.
#
# Commands:
#   hubot deploy status - Retrieve information about prod.
#   hubot deploy <pr-number> - Deploy a specific pull request to production by number.
#   hubot deploy rollback - Rollback production because something has gone wrong!
#
# Author:
#   farmdawgnation
cp = require 'child_process'

GitHubApi = require("github");

github = new GitHubApi({
    version: "3.0.0"
});

authenticate = ->
  github.authenticate
    type: "basic",
    username: process.env.DEPLOYISMO_USERNAME,
    password: process.env.DEPLOYISMO_PASSWORD

doRollback = (migrationCount) ->
  rollbackCommand = process.env.DEPLOYISMO_ROLLBACK_COMMAND.replace(/_migrationCount_/g, migrationCount)

  cp.exec rollbackCommand, (err, stdout, stderr) ->
    if err.code == 0
      return "Rollback completed successfully."
    else
      result = "Rollback error occured:"

      lines = stdout.split /\n/g
      result += "    " + line + "\n" for line in lines
      return result

doDeploy = (branchName, prNumber, callback) ->
  deployCommand = process.env.DEPLOYISMO_DEPLOY_COMMAND
  deployCommand = deployCommand.replace(/_branchName_/g, branchName)
  deployCommand = deployCommand.replace(/_prNumber_/g, prNumber)

  cp.exec deployCommand, callback

getProductionStatus = (callback) ->
  cp.exec process.env.DEPLOYISMO_STATUS_COMMAND, callback

getGithubPullRequest = (pullNumber, callback) ->
  authenticate()
  prQuery =
    user: process.env.DEPLOYISMO_REPO_USER
    repo: process.env.DEPLOYISMO_REPO_REPO
    number: pullNumber

  github.pullRequests.get prQuery, callback

getGithubPullRequestFiles = (pullNumber, callback) ->
  authenticate()
  prFilesQuery =
    user: process.env.DEPLOYISMO_REPO_USER
    repo: process.env.DEPLOYISMO_REPO_REPO
    number: pullNumber
    per_page: 100 # The max, sir.

  github.pullRequests.getFiles prFilesQuery, callback

getGithubCommitStatus = (commitSha, callback) ->
  authenticate()
  statusQuery =
    user: process.env.DEPLOYISMO_REPO_USER
    repo: process.env.DEPLOYISMO_REPO_REPO
    sha: commitSha

  github.statuses.get statusQuery, callback

latestCommitStatus = (statusArray) ->
  return null unless statusArray.length

  latestStatus = statusArray[0]
  latestStatus = status for status in statusArray when new Date(latestStatus.updated_at) < new Date(status.updated_at)

  latestStatus

isBranchUpToDateWithMaster = (branchName, callback) ->
  authenticate()
  compareQuery =
    user: process.env.DEPLOYISMO_REPO_USER
    repo: process.env.DEPLOYISMO_REPO_REPO
    base: branchName
    head: "master"

  github.repos.compareCommits compareQuery, (err, result) ->
    if err
      console.error "Github error: " + err
      callback(false)
    else
      callback(result.ahead_by == 0)

##         ##
## Exports ##
##         ##
module.exports = (robot) ->
  robot.respond /deploy status$/i, (msg) ->
    # Get the current deployment information for production. We define this as checking
    # to determine whether or not a custom branch is present by checking for a .deploy-lock
    # in the root of the server.
    msg.send "Checking the status of production."

    getProductionStatus (err, stdout, stderr) ->
      msg.send stdout

  robot.respond /deploy #?([0-9]+)$/i, (msg) ->
    # Handle the process of deploying a pull request to production. The following requirements
    # must be met for a branch to qualify for a deploy.
    #   1. Build status of the most recent SHA in the Pull Request must be success.
    #   2. Pull Request must be up-to-date with master at the time of the initial request.
    #      Subsequent commits will be auto-deployed to prod by Jenkins.
    #   3. Production can't already be deploy-locked.
    #
    # The process for completing a deploy is as follows:
    #   1. Execute the DEPLOYISMO_DEPLOY_COMMAND on the remote server with the SHA hash of
    #      the head commit and the pull request remote name as arguments.
    #   2. Comment on the pull request to note that it has been deployed to production.
    msg.send "Attempting to deploy pull request ##{msg.match[1]} to production."

    getProductionStatus (err, stdout, stderr) ->
      if /currently locked/.test(stdout)
        msg.send "A pull request is already deployed on prod. I cannot deploy another right now."
        return

      requestedPullRequestNumber = msg.match[1]

      getGithubPullRequest requestedPullRequestNumber, (err, pull) ->
        if err
          msg.send "Error retrieving pull request: " + err
          return

        if pull.merged || pull.state == "closed"
          msg.send "Sorry, I can't deploy a merged or closed pull request. Please look behind door number 2."
          return

        if pull.base.ref != "master"
          msg.send "You bozo. You can't ask me to deploy something that isn't targeted at master."
          return

        getGithubCommitStatus pull.head.sha, (err, commitStatusArray) ->
          if err
            msg.send "Error retrieving commit status " + err
            return

          latestStatus = latestCommitStatus(commitStatusArray)

          if latestStatus == "failure"
            msg.send "Pull request " + requestedPullRequestNumber + " has failing tests. Please correct failing specs or cukes before continuing."
            return

          if latestStatus == null || latestStatus.state != "success"
            msg.send "It doesn't look like pull request " + requestedPullRequestNumber + " has passed testing. Please wait for Jenkins."
            return

          isBranchUpToDateWithMaster pull.head.ref, (upToDate) ->
            unless upToDate
              msg.send "You need to merge master into your branch before I can deploy your pull request."
              return

            # At this point, we've passed all the checks. Well, shucks, buster. I guess it's time to
            # actually deploy something to the production server. YEEEHAWWWWW!
            msg.send "Pull request #" + requestedPullRequestNumber + " looks valid. Well done, sir. Go grab a beer from the kegerator while I work."

            doDeploy pull.head.ref, pull.number, (err, stdout, stderr) ->
              # Check return status.
              if err == null || err.code == 0
                msg.send "Deployment to production looks successful. Look to hear from Monit shortly."
              else
                resultMessage = "Something went wrong with deployment."
                resultMessage += "    " + line + "\n" for line in stdout.split("\n")
                msg.send resultMessage

  robot.respond /deploy rollback$/i, (msg) ->
    # Handle the process of a production rollback due to a faulty branch. The process for
    # executing a rollback is as follows:
    #   1. Count the number of migrations in the Pull Request.
    #   2. Execute DEPLOYISMO_ROLLBACK_COMMAND on the remote server, passing the number of
    #      migrations to roll back as an argument.
    msg.send "Attempting a rollback of production."

    getProductionStatus (err, stdout, stderr) ->
      unless /currently locked. Pull request # ([0-9]+)/.test(stdout)
        msg.send "Doesn't look like a pull request is active on prod."
        return

      activePullRequestNumber = stdout.matches(/currently locked. Pull request # ([0-9]+)/)[1]

      getGithubPullRequest activePullRequestNumber, (err, pull) ->
        if err
          msg.send "Error retrieving pull request: " + err
          return

        if pull.merged || pull.state == "closed"
          msg.send "Sorry, I can't deploy a merged or closed pull request. Please open another."
          return

        if pull.base.label != "master"
          msg.send "Sorry, I can't deploy pull requests that aren't targeted to master."
          return

        getGithubPullRequestFiles activePullRequestNumber, (err, pullFiles) ->
          if err
            msg.send "Error retrieving pull request files: " + err
            return

          migrations = migration for pullFile in pullFiles when pullFile.filename.matches(/db\/migrate\//)
          migrationCount = migrations.length

          msg.send "Rolling back pull request " + activePullRequestNumber ". " + migrationCount + " migrations found."
          msg.send doRollback(migrationCount)
