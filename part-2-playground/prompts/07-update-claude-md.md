Add these notes to "CLAUDE.md". We reach the servers with `ssh -F ../ssh/config test.playground.localhost`, and the same for "prod.playground.localhost". Merge requests go through the GitLab MCP server, pipelines and jobs through `glab`. The GitLab token is in ".env", so never print or commit it.

Add these deployment notes too. In CI, the hosts are "test-ssh" and "prod-ssh", the user is "deploy", and the CI variables are "SSH_PRIVATE_KEY" and "SSH_KNOWN_HOSTS". The systemd service "whoami" listens on port 80. Its access log is "/var/log/whoami/access.log" and its PID file is "/run/whoami/whoami.pid". A deploy copies the binary to a temp path and renames it. In CI, check "https://test.playground.internal" or "https://prod.playground.internal" with `curl --cacert "$CI_SERVER_TLS_CA_FILE"`.

Commit this, ".mcp.json" and ".envrc" to "main" and push it.
