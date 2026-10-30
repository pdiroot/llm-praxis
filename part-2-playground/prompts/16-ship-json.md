## Goal
Commit, push, open a merge request and merge it. Then start deploy-prod.

## Limits
- Merge request and merge through the GitLab MCP server.
- Start deploy-prod with `glab ci trigger`.
- Touch nothing else.

## Check
- Both servers show the new Commit.
- `curl 'https://test.playground.localhost/?format=json'` and the same for prod return JSON.

## Context
- The merge deploys to test; then start deploy-prod. Same flow as in iteration 1.
- Claude Code asks me before the deploy-prod command.
