Add a project subagent "troubleshooter" in ".claude/agents/troubleshooter.md". It should find out why the app fails on "test" or "prod", our local training containers.

It is read only: it connects with `ssh -F ../ssh/config`, looks at the unit status, the journal, "/var/log/whoami/access.log", CPU and memory, and changes nothing. Give it the tools "Bash" and "Read" and the model "haiku". It should report the cause, the evidence and what would stop this from happening again.
