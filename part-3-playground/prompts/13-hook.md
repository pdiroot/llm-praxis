Add a hook to the project settings in ".claude/settings.json". The event is PostToolUse, the matcher is "Edit|Write", and the command is this line:

f=$(jq -r .tool_input.file_path); case $f in *.py) uvx ruff format -q "$f" && uvx ruff check -q --fix "$f" >&2 || exit 2;; esac

Test the hook once with a Python file that has an error. Then commit it to "main" and push "main".
