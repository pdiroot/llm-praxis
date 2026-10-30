## Goal
Plan a small Go web app like traefik/whoami.
It answers each request in plain text with the host name, the IP addresses and the request headers.
It also shows the commit it was built from.

## Limits
- Standard library only. One static binary.
- The app writes an access log to a file and a PID file.
- Add a GitLab pipeline: build, deploy-test on a merge to main, then a manual deploy-prod.
- Write the plan only. Change no files.

## Check
- The plan lists the files, the pipeline jobs and how you will test the app.
- A deploy copies the binary to a temp path and renames it.
  It ships the systemd unit and restarts the service.
  Then it checks the Commit in the HTTP answer.

## Context
- Servers: test.playground.localhost and prod.playground.localhost, user deploy, systemd service `whoami`.
- The pipeline uses the image golang:1.27.3 and passes the binary as an artifact. Both deploys go over SSH.
- The access log is /var/log/whoami/access.log. The PID file is /run/whoami/whoami.pid.
