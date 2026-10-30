# LLM Praxis

Lessons on AI and Claude Code: slides and playgrounds, one directory for
each part. `README.md` lists the parts.

## Commits and pull requests

- Use Conventional Commits with a scope: `docs(part-1): fix the token slide`.
- Write the summary in lower case and in the imperative mood. Do not end it
  with a period.
- Keep the PR title at 64 characters or less. The squash merge adds
  ` (#N)`.
- Add a body only when the why is not obvious. Wrap it at 72 characters.
- Work on a branch named `type/slug`, such as `feat/part-2-playground`. Do
  not commit on `main`.

## Scope

- Keep the diff minimal.
- Make no drive-by changes.
- Add no new dependency without the owner's approval.

## Prohibitions

- Do not post a comment on a PR or an issue.
- Do not push, open a PR or merge without the owner's yes, unless a hook
  of the session allows the command.
- Do not add an AI trailer, a `Co-authored-by` line for an agent or a
  "Generated with" footer.
- Do not add `Signed-off-by`.
- Do not name the agent, the model or its version in a commit, a PR or a
  comment.

## Part 2 commands

Run these in `part-2-playground/`:

- `task check` runs `shellcheck`, `shfmt -i 2 -d` and `yamllint`.
- `task test` runs the `bats` tests.
