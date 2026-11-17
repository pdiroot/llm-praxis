/init This is "dice-roller", a command-line tool that rolls Dungeons & Dragons dice, such as `python3 -m dice_roller 4d6+2`. It is Python 3.13 or newer, standard library only.

The code lives in "demo/dice-roller" on GitLab: "https://gitlab.playground.localhost/demo/dice-roller". `glab` reaches it with the token in ".env".

Before each commit, run `uvx ruff format`, `uvx ruff check` and `python3 -m unittest`. The app should roll only the dice of Dungeons & Dragons: d4, d6, d8, d10, d12, d20 and d100. It should refuse any other die, and more than 100 dice in one roll.

Add ".env" and "__pycache__/" to ".gitignore". Commit "CLAUDE.md", ".gitignore" and ".envrc" to "main". Push "main".
