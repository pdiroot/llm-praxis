Create the skill "make-it-so" in ".claude/skills". It should take a feature request and do these steps:

1. Ask me questions until the request is clear.
2. The implementer builds the feature on a new branch.
3. The reviewer reviews the change.
4. The implementer fixes the high and critical findings. The reviewer checks again, until no high or critical finding is left.
5. Run `/simplify`.
6. Run `uvx ruff check` and the tests.
7. Push the branch. Open a merge request with `glab mr create`, and give me its link. Do not push to "main".

Commit the skill to "main". Push "main".
