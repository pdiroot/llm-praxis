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

## Code layout

- Put one blank line between the logical groups of statements: the setup,
  the work and the result of a function, the steps of a script, and the
  arrange, act and assert parts of a test.
- Split a function of more than 20 lines into named step functions, so that
  it reads as a list of steps. A heredoc or a data literal does not count.
- Define the functions of a script first. Run its steps at the bottom.
- Break a command of more than about 100 columns at its options, with `\`.
- Put a blank line between two entries at the top level of a YAML file,
  such as two tasks or two services.

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

- `task dev:check` runs `shellcheck`, `shfmt -i 2 -d` and `yamllint`.
- `task dev:test` runs the `bats` tests that need no running playground.
- `task dev:test-live` runs `task playground:reset`, the live `bats` tests, then `task playground:reset` again.
- `part-2-playground/README.md` lists the other tasks.
