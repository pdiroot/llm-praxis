/plan Add the deployment to ".gitlab-ci.yml" on the new branch "feat/deploy": "deploy-test" on a merge to "main", then a manual "deploy-prod". Use SSH as "deploy@test-ssh" and "deploy@prod-ssh", with CI variables "SSH_PRIVATE_KEY" and "SSH_KNOWN_HOSTS".

The app shows its commit and listens on port 80. Ship it as the service "whoami" with no restart policy, then `curl` the commit there.

Push without asking, open a merge request and give me the link.
