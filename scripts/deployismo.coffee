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
#   DEPLOYISMO_REPOSITORY: The repository in the form "user/reponame"
#   DEPLOYISMO_REMOTE_SERVER: Remote deployment server SSH login string.
#   DEPLOYISMO_DEPLOY_COMMAND: The deploy command to execute on the remote server.
#   DEPLOYISMO_ROLLBACK_COMMAND: The rollback command to execute on the remote server.
#
# Commands:
#   hubot deploy status - Retrieve information about prod.
#   hubot deploy <pr-number> - Deploy a specific pull request to production by number.
#   hubot deploy rollback - Rollback production because something has gone wrong!
#
# Author:
#   farmdawgnation
module.exports = (robot) ->
  robot.respond /deploy status$/i, (msg) ->
    # Get the current deployment information for production. We define this as checking
    # to determine whether or not a custom branch is present by checking for a .deploy-lock
    # in the root of the server.
    # TODO

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
    # TODO

  robot.respond /deploy rollback$/i, (msg) ->
    # Handle the process of a production rollback due to a faulty branch. The process for
    # executing a rollback is as follows:
    #   1. Count the number of migrations in the Pull Request.
    #   2. Execute DEPLOYISMO_ROLLBACK_COMMAND on the remote server, passing the number of
    #      migrations to roll back as an argument.
    # TODO
