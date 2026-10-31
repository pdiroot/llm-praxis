## Goal
Run the session-report skill for the last 24 hours, for this demo profile only.

## Limits
- Pass `--dir "$CLAUDE_CONFIG_DIR/projects"` to the analyzer. Do not read `~/.claude/projects`.
- Do not commit the report.

## Check
- The `root` value in the analyzer's JSON ends with `claude-config/projects`.
