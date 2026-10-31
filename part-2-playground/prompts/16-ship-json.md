Commit, push, open a merge request with the GitLab MCP server and merge it. The merge deploys to test. Then start deploy-prod with `glab ci trigger`. Touch nothing else.

Check that both servers show the new commit, and that `curl 'https://test.playground.localhost/?format=json'` and the same for prod return JSON.
