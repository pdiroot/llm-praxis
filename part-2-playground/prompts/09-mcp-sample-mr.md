## Goal
Fix the README typo from the open issue in demo/sample-service. Open a merge request for it.

## Limits
- Clone demo/sample-service to `../sample-service` over SSH, with the same SSH config.
- Fix the typo on the branch `fix/readme-typo`, commit and push it.
- Then open the merge request with the GitLab MCP server.
- Change only the word "servce". Do not merge. Do not touch the other merge request.

## Check
- The diff of the merge request changes one word.
- The description closes the issue.

## Context
- The README says "servce" in the line about `GET /health`. The right word is "service".
- Use a Conventional Commits subject.
