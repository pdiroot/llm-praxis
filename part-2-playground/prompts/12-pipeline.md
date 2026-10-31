Add a GitLab pipeline on a new branch: build, deploy-test on a merge to main, then a manual deploy-prod. Both deploys go over SSH to "test.playground.localhost" and "prod.playground.localhost", user "deploy", systemd service "whoami".

The app now also shows the commit it was built from. The access log goes to "/var/log/whoami/access.log" and the PID file to "/run/whoami/whoami.pid".

The pipeline uses the image "golang:1.27.3" and passes the binary as an artifact. A deploy copies the binary to a temp path and renames it, ships the systemd unit, restarts the service, and checks the commit in the HTTP answer.

Add these notes to CLAUDE.md: we reach the servers with `ssh -F ../ssh/config test.playground.localhost`, and the same for prod.playground.localhost. Merge requests go through the GitLab MCP server, pipelines and jobs through `glab`.

Then push, open a merge request with the GitLab MCP server and merge it. Show me the pipeline link and do not wait for it.
