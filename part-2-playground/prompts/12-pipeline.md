Add a GitLab pipeline on a new branch: "build", "deploy-test" on a merge to "main", then a manual "deploy-prod". Both deploys go over SSH to "test.playground.localhost" and "prod.playground.localhost", user "deploy", systemd service "whoami".

The app should now also show the commit it was built from. The access log should go to "/var/log/whoami/access.log" and the PID file to "/run/whoami/whoami.pid".

The pipeline should use the image "golang:1.27.3" and pass the binary as an artifact. A deploy should copy the binary to a temp path and rename it, ship the systemd unit, restart the service, and check the commit in the HTTP answer.

Then push, open a merge request with the GitLab MCP server and merge it. Show me the pipeline link and do not wait for it.
