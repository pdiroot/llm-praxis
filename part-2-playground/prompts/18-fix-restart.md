Restart the app on "prod". Then set "Restart=on-failure" in the systemd unit in the repository, on a new branch. Change the first line of the answer to "Hello again from whoami", so we can see the new version.

Add two lines to "CLAUDE.md": each service must restart when it dies, and the logs are in `journalctl -u whoami`.
