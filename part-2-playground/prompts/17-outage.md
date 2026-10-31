The app on prod is down. Connect with `ssh -F ../ssh/config prod.playground.localhost` and find out what happened.

This is read only: do not restart or edit anything. Look at the unit status, the journal, the access log, CPU and memory. The service is "whoami", and its logs are in `journalctl -u whoami` and "/var/log/whoami/access.log".

Name the cause, the evidence for it, and what would stop it from happening again.
