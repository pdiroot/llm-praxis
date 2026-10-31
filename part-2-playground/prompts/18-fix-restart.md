Restart the app on prod, and make the unit restart it when it dies. The first unit has no restart policy, so the process stayed down. Set `Restart=on-failure` in the systemd unit in the repository.

Ship the fix to test and prod with a branch, a merge request and the normal pipeline. Add two lines to CLAUDE.md: each service must restart when it dies, and the logs are in `journalctl -u whoami`.

Check that the unit on both servers shows `Restart=on-failure` and that prod answers after the deploy. I will kill the process again to test the fix.
