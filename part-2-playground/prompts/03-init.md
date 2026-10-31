/init This is whoami, a small Go web app that answers who called it: the host name, the IP addresses and the request headers. We build it here to learn Claude Code, so the folder is still empty and the notes come from me, not from the code.

The code lives in demo/whoami on https://gitlab.playground.localhost. The design is simple: one static binary, standard library only, running as the systemd service whoami.

We run `go fmt ./...`, `go vet ./...` and `go test ./...` before each commit, because a broken build should never reach a server.

The pipeline is there so that nobody deploys by hand. A merge to main goes to test by itself, and prod is a manual job, so a person always decides. We reach the servers with `ssh -F ../ssh/config test.playground.localhost`, and the same for prod.playground.localhost.

Merge requests go through the GitLab MCP server, pipelines and jobs through glab.

Keep CLAUDE.md short and put no secrets in it. Then commit it to main, push it and run `git remote set-head origin --auto`.
