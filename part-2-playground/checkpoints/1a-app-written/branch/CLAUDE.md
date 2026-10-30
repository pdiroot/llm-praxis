# whoami

A Go app like `traefik/whoami`: it answers each request with the host name,
the IP addresses and the request headers, and shows the commit it was built from.

## Environment

- Code: https://gitlab.playground.localhost, project demo/whoami. A merge to `main` deploys to `test`. The deploy to `prod` is a manual job.
- Servers: `ssh -F ../../ssh/config test.playground.localhost`, the same for `prod`. User `deploy`, systemd service `whoami`.
- Merge requests go through the GitLab MCP server. Pipelines and jobs go through `glab`.

## Rules

- Before each commit, run `go fmt ./...`, `go vet ./...` and `go test ./...`.
