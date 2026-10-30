## Goal
The app on prod is down. Connect to the server and find out what happened.

## Limits
- Read only. Look at the unit status, the journal, the access log, CPU and memory.
- Do not restart or edit anything.

## Check
- Name the cause and the evidence for it.
- Say what would stop it from happening again.

## Context
- Server: prod.playground.localhost, user deploy. Use `ssh -F ../ssh/config prod.playground.localhost`.
- The service is `whoami`. Logs: `journalctl -u whoami` and /var/log/whoami/access.log.

Change nothing yet.
