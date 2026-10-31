Add a "?format=json" parameter on a new branch. It should return the same data as JSON, and the plain-text answer must not change. The earlier decisions are in "CLAUDE.md" and in the summary.

Use red/green TDD: write a failing test, show that it fails, then write the smallest code that passes.

Run the checks from "CLAUDE.md", then check the app with `curl` in both formats.
