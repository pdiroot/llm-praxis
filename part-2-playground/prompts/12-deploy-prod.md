## Goal
Deploy to production, then tell me the output.

## Limits
- Start the manual deploy-prod job with `glab ci trigger`.
- Use the pipeline of the last merge to main.
- Follow the job with `glab ci trace`.

## Check
- Report the job status and the last lines of the log.
- Report the Commit that https://prod.playground.localhost shows.

## Context
- The binary is the artifact that test got. glab reads GITLAB_TOKEN and GITLAB_HOST from `.env`.
- The ask rule makes you ask me first.
