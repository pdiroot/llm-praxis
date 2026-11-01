/plan Add the deployment to ".gitlab-ci.yml" on the new branch "feat/deploy": "deploy-test" on a merge to "main", then a manual "deploy-prod". "CLAUDE.md" has the server details.

The app should show its commit. Each deploy ships the binary and a minimal systemd unit with no restart policy, then checks that commit with `curl` on the server.

Push the branch without asking me, open a merge request and give me the link.
