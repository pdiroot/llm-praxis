## Goal
Add one line to CLAUDE.md: before each commit, run `go fmt ./...`, `go vet ./...` and `go test ./...`.

## Limits
- One line. Change nothing else in the file.
- Do not commit yet.

## Check
- Show me the diff of CLAUDE.md.

## Context
- This is a Go app. Claude cannot guess the check commands from an empty folder.
- CLAUDE.md loads at the start of every session.
