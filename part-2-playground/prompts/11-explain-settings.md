Read "../claude-config/settings.json", the demo user settings. Explain the hook, the deny rule and the ask rules in plain words, and say which part is only guidance and not a security boundary.

Then add one line to CLAUDE.md: the GitLab token is in ".env", so never print or commit it. Change nothing else, and do not read ".env".

I saved GITLAB_TOKEN in ".env". The hook loads that file, so `glab` works at once.
