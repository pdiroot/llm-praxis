# Part 3: Claude Code 201

This playground is a GitLab on your Mac with one empty project,
`demo/dice-roller`. Claude Code builds a dice roller for Dungeons & Dragons
in Python, while a second Claude Code session watches GitLab for merge
requests.

The deck "Claude Code 201" is your guide. It has the theory on the left, and
on the right the prompts and commands to copy.

| Iteration | Slides | Result | You learn |
|-----------|--------|--------|-----------|
| 1, the loop | 5 to 11 | `CLAUDE.md`, a status line, and a second session that checks GitLab each minute | `/loop`, the four kinds of loop, routines, a first plugin |
| 2, the subagents | 12 to 19 | The first version of the dice roller, built by hand, then a web app with a dark theme for Dungeons & Dragons, built under `/goal` | Subagents, a model and an effort for each job, the advisor, `/goal` |
| 3, the skill | 20 to 25 | Advantage and disadvantage, added with one command | Skills, `/make-it-so`, a review of a colleague's merge request |

Slide 26 starts the second session, Claude Code 202. It continues from the
state at the end of iteration 3.

| Iteration | Slides | Result | You learn |
|-----------|--------|--------|-----------|
| 4, the plugins | 29 to 35 | A better `/make-it-so`, and its evals | Marketplaces, `skill-creator` |
| 5, the workflow | 36 to 40 | A table of the dice notations of four tools, and the next features | Workflows |
| 6, parallel sessions | 41 to 45 | Keep and drop, and rerolls, built at the same time | Agent view, worktrees, three ways to run many agents |

Slides 46 to 49 close the session. Slides 50 and 51 are an extra on Remote
Control, and slides 52 and 53 are an appendix. A rehearsal of 201 measured
approximately 35 minutes of live steps. With the talk, plan for
approximately 70 minutes. Alone, plan for 2 hours.

The part 2 playground (Claude Code 101 and 102) teaches the basics. This
playground does not repeat them.

## What you need

- A Mac on Apple silicon. On Linux some scripts need changes, and on Windows
  more of them do. Any AI harness can help you with these changes.
- Docker Desktop, running, with at least 8 GB of memory. GitLab alone uses
  approximately 4 GB.
- A Claude plan. The session uses your own plan limits. A workflow uses many
  more tokens than one session.
- Claude Code 2.1.312 or later.
- Python 3.13 or later as `python3`.
- `task`, `jq`, `glab`, `direnv`, `uv`, `openssl`, `git`, `curl`, `ssh` and
  `ssh-keygen`.
- Free local ports: 80, 443, 2222 and 8101 (the web app). The part 2
  playground uses 80, 443 and 2222, so stop it first: `task playground:stop`
  in `part-2-playground`.

```shell
curl -fsSL https://claude.ai/install.sh | bash
brew install go-task jq glab direnv uv python
```

## Run the playground

Clone the repository, then run each command in `part-3-playground`.

```shell
git clone https://github.com/pdiroot/llm-praxis.git
cd llm-praxis/part-3-playground
task playground:start
task slides:open
task claude:start
```

1. `task playground:start` starts GitLab and Traefik. The first start takes
   approximately 2 minutes.
2. macOS asks once for your admin password, to trust the local root certificate
   authority (CA). Refer to [What this changes on your Mac](#what-this-changes-on-your-mac).
3. `task slides:open` opens the deck. Start at slide 1 and go through it in
   order.
4. `task claude:start` starts the main Claude Code session in an isolated
   profile. When Claude Code asks, log in in the browser. Choose "Yes, I
   trust this folder": the default answer exits Claude Code.
5. Iteration 1 tells you when to start a second session: run
   `task claude:start` again, in a second terminal.

Use the **Copy** button on each prompt. Claude can give a different result
each time, so read what it does before you continue.

Run `task playground:preflight` before a talk. It tests the playground, then
lists the checks that you must do by hand. After a reset, start
`task claude:start` one time and exit, so that the official marketplace is
added again. Turn off Do Not Disturb, so that the
alert of the loop shows.

## Accounts and addresses

| Address | Account | Password |
|---------|---------|----------|
| <https://gitlab.playground.localhost> | `demo`, the owner of `demo/dice-roller` | `P@ssw0rd` |
| <https://gitlab.playground.localhost> | `root` | `P@ssw0rd` |

The password is public, so do not expose these ports. The containers listen
only on your own computer.

## The isolated sessions

`task claude:start` clones `demo/dice-roller` to `~/llm-praxis-201`, if it
is not there. Then it starts Claude Code with its own empty profile. Your own
Claude Code settings, plugins and sessions stay out of it. Set
`PG_DEMO_HOME` to use a different folder.

- `task claude:start` in a second terminal starts a second session in the
  same clone and profile.
- `task claude:continue` continues the last conversation.
- A guard refuses to start when a parent folder has `CLAUDE.md`, `AGENTS.md` or
  `.mcp.json`.

The playground makes a GitLab token for `demo` and writes it to `.env` in the
clone. `direnv` loads it when a session starts. Part 2 shows how to make a
token yourself.

Warning: Do not copy the allow rules for `glab`, `git push`, `osascript`
and `uvx ruff` to a real project. They are for this playground only.
The profile does not isolate your home folder, so a shell command in the
session can read `~/.ssh` and `~/.claude`.

## Commands

| Command | What it does |
|---------|--------------|
| `task playground:status` | Shows the containers and the state of GitLab |
| `task playground:preflight` | Checks the playground before a talk |
| `task claude:start` | Starts a demo session. Run it in a second terminal for the loop |
| `task claude:continue` | Continues the last conversation of the main session |
| `task claude:team` | Starts a main session with agent teams turned on |
| `task playground:stop` | Stops the containers and keeps the data |
| `task playground:start` | Provisions a new playground, or resumes a stopped one |
| `task playground:reset` | Empties the project and the sessions of the demo profile. The login stays. Use it for a new attempt |
| `task playground:terminate` | Logs the demo profile out, and deletes the containers, the volumes, the demo folder and `runtime/`. The root CA stays |
| `task demo:merge-request` | Opens the merge request of a colleague, for the loop to find |
| `task slides:open` | Builds the deck and opens it |

## What this changes on your Mac

- It adds a root CA to the System keychain, named "Playgrounds Root CA". The
  scripts make this CA on your Mac, and its key stays in
  `~/.config/playgrounds/tls`. All playgrounds use it, so
  `task playground:terminate` keeps it.
- It makes the folder `~/llm-praxis-201`.
- It starts Docker containers and volumes in the Compose project
  `llm-praxis-part-3`.

To remove everything, run these commands:

```shell
task playground:terminate
sudo security delete-certificate -c "Playgrounds Root CA" /Library/Keychains/System.keychain
rm -rf ~/.config/playgrounds/tls
```

## If something goes wrong

| Problem | What to do |
|---------|------------|
| `task playground:start` says that part 2 runs | Run `task playground:stop` in `part-2-playground` |
| `task playground:start` stops at a port | Find the program with `lsof -nP -iTCP:443 -sTCP:LISTEN`, and stop it |
| GitLab does not answer | Run `task playground:status`, then `docker compose logs gitlab`. Check the memory of Docker Desktop |
| The alert of the loop does not show | Turn off Do Not Disturb. Allow notifications for your terminal in System Settings |
| `/plugin install` says the marketplace is missing | Run `/plugin marketplace add anthropics/claude-plugins-official`, then install again |
| The workflow is slow | The agents read the web. The deck has the result of a rehearsal |
| A session goes wrong | Run `task playground:reset`, then start again from iteration 1 |

## Develop

Run these in `part-3-playground/`:

- `task dev:check` runs `shellcheck`, `shfmt -i 2 -d` and `yamllint`, and
  checks that `slides/prompts.js` is current.
- `task dev:test` runs the `bats` tests.
- `task slides:build` makes `slides/prompts.js` from `prompts/*.md`.
