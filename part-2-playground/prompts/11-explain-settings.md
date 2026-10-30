## Goal
Read the demo user settings and explain each part in plain words.

## Limits
- Read only. Change nothing.
- Read `demo/settings.json`, not `.claude/settings.json`.
- Do not read `.env`. Never print the token.
- Then add one line to CLAUDE.md: the GitLab token is in `.env`. Never print or commit it.

## Check
- Name the hook, the deny rule and the ask rules, and say what each one does.
- Say which part is only guidance and not a security boundary.

## Context
- I saved GITLAB_TOKEN and GITLAB_HOST in `.env`. The hook loads that file, so `glab` works at once.
