/plan Add the deployment to ".gitlab-ci.yml" on the same branch: "deploy-test" on a merge to "main", then a manual "deploy-prod". Both deploys go over SSH to the hosts "test-ssh" and "prod-ssh", user "deploy", systemd service "whoami", with the CI variables "SSH_PRIVATE_KEY" and "SSH_KNOWN_HOSTS".

The app should now also show the commit it was built from, and listen on port 80. The access log should go to "/var/log/whoami/access.log" and the PID file to "/run/whoami/whoami.pid".

A deploy should use the binary from "build", copy it to a temp path and rename it, ship the systemd unit, restart the service, and check the commit at "https://test.playground.internal" or "https://prod.playground.internal" with `curl --cacert "$CI_SERVER_TLS_CA_FILE"`. Keep the first unit minimal, with no restart policy.

Then push, open a merge request with the GitLab MCP server and give me the link. Do not merge it: I review and merge it myself.
