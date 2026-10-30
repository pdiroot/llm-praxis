## Goal
Push the branch. Open a merge request to main in demo/whoami and merge it.

## Limits
- Use the GitLab MCP server.
- Squash is fine. Delete the source branch after the merge.
- Merge only this merge request.

## Check
- Show the pipeline of the merge and the status of deploy-test.
- Open https://test.playground.localhost. The Commit matches the merge.

## Context
- A merge to main starts the build and deploy-test. The deploy-prod job waits for a click.
- I ask you to merge, so the merge is my request.
