## Goal
Restart the app on prod. Make the unit restart the app when it dies. Ship the fix to test and prod.

## Limits
- Set `Restart=on-failure` in the systemd unit, in the repository.
- Use a branch, a merge request and the normal pipeline.
- Add two lines to CLAUDE.md: each service must restart when it dies, and the logs are in `journalctl -u whoami`.

## Check
- The unit on both servers shows `Restart=on-failure`.
- The app answers on prod after the deploy.

## Context
- The first unit has no restart policy, so the process stayed down.
- I will kill the process again to test the fix.
