## Goal
Add a `?format=json` parameter. It returns the same data as JSON. Use red/green TDD.

## Limits
- Write a failing test first. Run it and show that it fails.
- Then write the smallest code that passes.
- The plain-text answer must not change.
- Work on a new branch.

## Check
- Run `go fmt ./...`, `go vet ./...` and `go test ./...`. All pass.
- Check the app with `curl` in both formats.

## Context
- The earlier decisions about the app are in CLAUDE.md and in the summary.
- Next, a merge request and a deploy.
