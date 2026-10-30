## Goal
Add a short "Environment" section to CLAUDE.md. Then commit CLAUDE.md to main and push it.

## Limits
- At most 8 lines. No secrets, no tokens, no passwords.
- Only what you cannot guess from the code.
- Do not change the other lines of CLAUDE.md.

## Check
- CLAUDE.md is on origin/main.
- Run `git remote set-head origin --auto` after the push.

## Context
- The code is at https://gitlab.playground.localhost, project demo/whoami.
- A merge to main deploys to test. The deploy to prod is a manual job.
- Reach the servers from the clone with `ssh -F ../ssh/config test.playground.localhost`. The same for prod.
- The GitLab MCP server (https://gitlab.playground.localhost/api/v4/mcp) handles merge requests. `glab` handles pipelines and jobs.
