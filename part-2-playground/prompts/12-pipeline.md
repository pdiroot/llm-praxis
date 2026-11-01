/plan Add the deployment to ".gitlab-ci.yml" on the new branch "feat/deploy": "deploy-test" on a merge to "main", then a manual "deploy-prod". "CLAUDE.md" has the server details.

The app should also show its commit. Each deploy ships the binary and a minimal systemd unit with no restart policy, then checks that commit.

Push the branch without asking me, open a merge request with the GitLab MCP server and give me the link. I merge it.
