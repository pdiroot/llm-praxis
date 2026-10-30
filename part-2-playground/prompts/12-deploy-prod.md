## Goal
Deploy to production, then tell me the output.

## Limits
- Start the manual job with `glab ci trigger deploy-prod -b main`.
- Follow the job with `glab ci trace`.

## Check
- First check that https://test.playground.localhost shows the Commit of the merge.
- Report the job status and the last lines of the log.
- Report the Commit that https://prod.playground.localhost shows.

## Context
- The binary is the artifact that test got. glab reads GITLAB_TOKEN and GITLAB_HOST from `.env`.
- Claude Code asks me before this command.
