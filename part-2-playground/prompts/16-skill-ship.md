Add a project skill "ship" in ".claude/skills/ship/SKILL.md". Set `disable-model-invocation: true`, because it deploys to production.

Its steps: commit, push, open a merge request with the GitLab MCP server and merge it. When the deployment to "test" succeeds, start "deploy-prod" with `glab ci trigger`, and give me the link to test the app myself.
