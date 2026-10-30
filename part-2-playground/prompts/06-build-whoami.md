## Goal
Build the plan on a new branch. Run the app locally and check it with `curl`. Commit on the branch.

## Limits
- Follow the approved plan, with my edit.
- Name the branch `feat/whoami`. Do not commit on main.
- One commit with a Conventional Commits subject.

## Check
- Run `go fmt ./...`, `go vet ./...` and `go test ./...`. All pass.
- Show the `curl` output and `git log --stat -1`.

## Context
- The review compares the branch with main, so the new files must be committed.
- CLAUDE.md has the check commands.
