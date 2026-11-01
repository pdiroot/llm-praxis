Add these notes to "CLAUDE.md". We reach the servers with `ssh -F ../ssh/config test.playground.localhost`, and the same for "prod". Merge requests use the GitLab MCP server, pipelines use `glab`. Never print or commit ".env". CI reaches the servers as "deploy@test-ssh" and "deploy@prod-ssh", with the variables "SSH_PRIVATE_KEY" and "SSH_KNOWN_HOSTS". The app runs as the service "whoami" on port 80.

Commit this, ".mcp.json" and ".envrc" to "main" and push it.
