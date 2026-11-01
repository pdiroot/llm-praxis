Add these notes to "CLAUDE.md". We reach the servers with `ssh -F ../ssh/config test.playground.localhost`, and the same for "prod.playground.localhost". Merge requests go through the GitLab MCP server, pipelines and jobs through `glab`. The GitLab token is in ".env", so never print or commit it.

Commit this to the default branch and push it.
