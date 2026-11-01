Restart the app on "prod". Then set "Restart=on-failure" in the systemd unit in the repository, on a new branch.

Add two lines to "CLAUDE.md": each service must restart when it dies, and the logs are in `journalctl -u whoami`.
