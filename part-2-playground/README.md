# Part 2: a playground for one repository

This playground is a small company on your Mac: a GitLab, a runner, an HTTPS
proxy and two servers, `test` and `prod`. You use Claude Code to build a small
web app, `whoami`, and to ship it through a pipeline to production.

The deck "Claude Code 101" is your guide. It has the theory on the left, and on
the right the prompts and commands to copy.

| Iteration | Slides | Result | You learn |
|-----------|--------|--------|-----------|
| 1 | 13 to 21 | The app runs locally, and a pipeline tests and builds it | `CLAUDE.md`, permission modes, plan mode, reviews, `/voice` |
| 2 | 22 to 28 | Claude reads GitLab | Claude in Chrome, MCP, `glab`, computer use, the context window |
| 3 | 29 to 34 | The app has JSON and runs on `test` and `prod` | Tests first, a merge request, a deployment pipeline |
| 4 | 35 to 37 | An outage on `prod` is found and fixed | Troubleshooting with Claude Code |

The live talk takes 45 minutes. Alone, plan for two hours.

## What you need

- A Mac on Apple silicon. On Linux some scripts need changes, and on Windows
  more of them do. Any AI harness can help you with these changes.
- Docker Desktop, running, with at least 8 GB of memory. GitLab alone uses
  about 4 GB.
- A Claude plan. The session uses your own plan limits.
- Claude Code 2.1.312 or later.
- Chrome with the Claude in Chrome extension, for iteration 2. Use a Chrome
  profile that has no personal tabs, and sign in to GitLab there as `demo`.
- `task`, `go` 1.27, `jq`, `glab` 1.126.0, `direnv`, `openssl`, `git`, `curl`, `ssh` and
  `ssh-keygen`.
- Free local ports: 80, 443, 2222, 2201 and 2202.
- The free network `172.30.42.0/24`. A VPN can use the same network.

```shell
curl -fsSL https://claude.ai/install.sh | bash
brew install go-task go jq glab direnv
```

The names `*.playground.localhost` need no change in `/etc/hosts`.

## Run the playground

Clone the repository, then run each command in `part-2-playground`.

```shell
git clone https://github.com/pdiroot/llm-praxis.git
cd llm-praxis/part-2-playground
task playground:start
task playground:smoke
task slides:open
task claude:start
```

1. `task playground:start` builds and starts everything. The first start takes
   a few minutes. GitLab alone needs about 2 minutes.
2. macOS asks once for your admin password, to trust the local root certificate
   authority (CA). See [What this changes on your Mac](#what-this-changes-on-your-mac).
3. `task playground:smoke` deploys a small test app four times, then empties
   the servers.
4. `task slides:open` opens the deck. Start at slide 1 and go through it in
   order.
5. `task claude:start` starts Claude Code in an isolated session. Log in in the
   browser when it asks. Choose "Yes, I trust this folder": the default answer
   exits Claude Code.

Use the deck for the rest. Use the **Copy** button on each prompt. Claude can
give a different result each time, so read what it does before you continue.

Run `task playground:preflight` before a talk. It tests the playground, then
lists the checks that need your eyes. Sign in to GitLab as `demo` in Chrome
before the talk, and make that Chrome your default browser.

## Accounts and addresses

| Address | Account | Password |
|---------|---------|----------|
| <https://gitlab.playground.localhost> | `demo`, the owner of `demo/whoami` | `P@ssw0rd` |
| <https://gitlab.playground.localhost> | `root` | `P@ssw0rd` |

The app runs at <https://test.playground.localhost> and
<https://prod.playground.localhost>. The password is public, so do not expose
these ports. The containers listen only on your own computer.

To connect to a server yourself:

```shell
ssh -F ~/llm-praxis-demo/ssh/config test.playground.localhost
```

## The isolated session

`task claude:start` clones `demo/whoami` to `~/llm-praxis-demo`, if it is not
there. Then it starts Claude Code with its own empty profile. Your own Claude
Code settings, plugins and sessions stay out of it. Set `PG_DEMO_HOME` to use a
different folder.

- `task claude:continue` continues the last conversation.
- `task claude:start -- -r` picks an older conversation.
- A guard refuses to start when a parent folder has `CLAUDE.md`, `AGENTS.md` or
  `.mcp.json`.

Warning: The profile does not isolate your home folder. A shell command in the
session can read `~/.ssh` and `~/.claude`. The allow rules for `glab` and
`git push` are for this playground only. Do not copy them to a real project.

## Make the GitLab token

Iteration 2 needs a token for `glab`, on slide 25.

1. Sign in to <https://gitlab.playground.localhost> as `demo`.
2. Use the link on the slide, or open
   <https://gitlab.playground.localhost/-/user_settings/personal_access_tokens>.
3. Make a token with the `api` scope. Set the expiration date to tomorrow: the
   page suggests 30 days.
4. Copy the token. GitLab shows it only one time.
5. Write it from the clipboard to `.env`, and let `direnv` load that file:

   ```shell
   echo "GITLAB_TOKEN=$(pbpaste)" > ~/llm-praxis-demo/whoami/.env
   echo dotenv > ~/llm-praxis-demo/whoami/.envrc
   direnv allow ~/llm-praxis-demo/whoami
   ```

6. Exit Claude Code and run `task claude:continue`.

Never put the token in a prompt or a commit. The demo session starts through
`direnv exec`, so it reads `.env` at each start. A token that you save later
needs a restart. In your own projects, add the `direnv` hook to your shell and
start `claude` in the folder.

## Commands

| Command | What it does |
|---------|--------------|
| `task playground:status` | Shows the containers and the state of GitLab |
| `task playground:stop` | Stops the containers and keeps the data |
| `task playground:start` | Provisions a new playground, or resumes a stopped one |
| `task playground:reset` | Brings GitLab, the servers and the demo profile back to the start. Use it for a new attempt |
| `task playground:terminate` | Deletes the containers, the volumes, the demo folder and `runtime/`. The root CA stays |
| `task slides:open` | Builds the deck and opens it |

## What this changes on your Mac

- It adds a root CA to the System keychain, named "Playgrounds Root CA". The
  scripts make this CA on your Mac, and its key stays in
  `~/.config/playgrounds/tls`. All playgrounds use it, so
  `task playground:terminate` keeps it.
- It makes the folder `~/llm-praxis-demo`.
- It starts Docker containers and volumes in the Compose project
  `llm-praxis-part-2`.

To remove everything, run these commands:

```shell
task playground:terminate
sudo security delete-certificate -c "Playgrounds Root CA" /Library/Keychains/System.keychain
rm -rf ~/.config/playgrounds/tls
```

## If something goes wrong

| Problem | What to do |
|---------|------------|
| `task playground:start` stops at a port | Find the program with `lsof -nP -iTCP:443 -sTCP:LISTEN`, and stop it |
| The network does not start, or a VPN breaks | Turn off the VPN. It can use `172.30.42.0/24` |
| GitLab does not answer | Run `task playground:status`, then `docker compose logs gitlab`. Check the memory of Docker Desktop |
| The browser does not trust a page | Run `task playground:start` again, and let macOS trust the root CA |
| Auto mode blocks a step | Read the reason. Slide 34 has a second prompt that states your intent |
| A dialog recommends an LSP plugin | Press `Esc`. The session does not need the plugin |
| Claude repeats a command and does not stop | Press `Esc` and ask for one check with `glab` |
| A session goes wrong | Run `task playground:reset`, then start again from iteration 1 |

## Develop

- `prompts/` has the prompts of the session, one file each.
- `task slides:build` rebuilds `slides/prompts.js` from `prompts/`.
- `task dev:check` runs `shellcheck`, `shfmt` and `yamllint`. It needs these
  tools on your Mac.
- `task dev:test` runs the `bats` tests that need no playground.
- `task dev:test-live` resets the playground, runs the tests that need it, then
  resets it again.
