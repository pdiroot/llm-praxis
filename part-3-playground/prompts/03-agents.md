Create two subagents in ".claude/agents".

"implementer" is a Python developer. It should run on Sonnet. It should write the code and its tests. It should run `uvx ruff format`, `uvx ruff check` and `python3 -m unittest` until they pass. Then it should commit to the current branch.

"reviewer" is a Python code reviewer. It should run on Opus with medium effort. It should review a change for bugs, security, edge cases and design, and give each finding a severity. It should not change any file.

Commit the subagents to "main". Push "main".
