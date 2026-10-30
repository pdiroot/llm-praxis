# whoami

A Go app like `traefik/whoami`: it answers each request with the host name,
the IP addresses and the request headers, and shows the commit it was built from.

## Environment

- Code: https://gitlab.playground.localhost, project demo/whoami. A merge to `main` deploys to `test`. The deploy to `prod` is a manual job.
- Servers: `ssh -F ../../ssh/config test.playground.localhost`, the same for `prod`. User `deploy`, systemd service `whoami`.
- Merge requests go through the GitLab MCP server. Pipelines and jobs go through `glab`.

## Rules

- Before each commit, run `go fmt ./...`, `go vet ./...` and `go test ./...`.
- The access log `/var/log/whoami/access.log` holds the time, the remote address, the method, the path and the status. It never holds a header: Authorization and Cookie must not reach a file. The answer echoes the caller's own headers on purpose.
- The PID file `/run/whoami/whoami.pid` is written in the unit's `RuntimeDirectory`, and the unit runs as `nobody`, not root. The PID is no secret, so the file stays world-readable.
- The GitLab token is in `.env`. Never print it and never commit it.
- Logs are in `journalctl -u whoami`.
- Each service must restart when it dies: the unit sets `Restart=on-failure`.
