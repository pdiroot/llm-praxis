Restart the app on "prod", and make the unit restart it when it dies. The first unit has no restart policy, so the process stayed down. Set "Restart=on-failure" in the systemd unit in the repository, on a new branch.

Add two lines to "CLAUDE.md": each service must restart when it dies, and the logs are in `journalctl -u whoami`.
