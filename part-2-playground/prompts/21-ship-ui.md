## Goal
Commit and push. Open a merge request, merge it, deploy to test and prod. Check both pages in the browser.

## Limits
- Merge through the GitLab MCP server. Start deploy-prod with `glab ci trigger`.
- Touch nothing else.

## Check
- Use Claude in Chrome on https://test.playground.localhost and https://prod.playground.localhost.
- Both pages show the new UI and the same Commit.

## Context
- The same flow as before.
- Claude Code asks me before the deploy-prod command.
