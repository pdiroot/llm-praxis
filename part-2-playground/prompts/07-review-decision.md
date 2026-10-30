## Goal
Fix the findings of the security review that you agree with. Write the decision about the access log and the PID file into CLAUDE.md.

## Limits
- One commit for the fixes. A separate commit for CLAUDE.md.
- Name each finding that you reject, with the reason.
- Add at most 3 lines to CLAUDE.md.

## Check
- `go test ./...` passes.
- Show the commits and the new lines of CLAUDE.md.

## Context
- The next session must keep this decision.
- Look at the access log and the headers it writes, the PID file and its folder, and the headers echoed back.
