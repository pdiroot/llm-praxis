# Part 2: a playground for one repository

A local GitLab, a runner, a Traefik proxy and two small servers (`test` and
`prod`). In the session, Claude Code builds a small app, `whoami`, and ships
it through a pipeline from `test` to `prod`. All of it runs in Docker on
your Mac.

## Requirements

- A Mac on Apple silicon, with Docker Desktop running
- `task`, `openssl`, `jq`, `git` and `curl`
- `glab` 1.126.0
- Claude Code 2.1.312 or later, and a Claude plan to log in with
- To change the scripts: `bats`, `shellcheck`, `shfmt` and `yamllint`

The names `*.playground.localhost` need no change in `/etc/hosts`.

## Start

Run every command in this directory.

```shell
task start
```

- The first run makes the root CA in `~/.config/playgrounds/tls`. All
  playgrounds share this CA, and no script replaces it.
- If macOS does not trust the CA yet, macOS asks once for your admin
  password (`sudo security add-trusted-cert`). Later runs ask nothing.
- GitLab needs about 5 minutes to start.
- `task start` ends when GitLab, the runner, the `demo/whoami` project and
  the two servers are ready.

Then prove the playground:

```shell
task smoke
```

`task smoke` deploys a small smoke app four times and empties the servers
afterwards. Run `task preflight` before each rehearsal and before the
session.

## Accounts

| URL | Account | Password |
|-----|---------|----------|
| https://gitlab.playground.localhost | `root` | `P@ssw0rd` |
| https://gitlab.playground.localhost | `demo` | `P@ssw0rd` |

`demo` owns the project `demo/whoami`. The deployed app is at
https://test.playground.localhost and https://prod.playground.localhost.
SSH ports on `127.0.0.1`: GitLab `2222`, `test` `2201`, `prod` `2202`.

## Run the session

```shell
task demo
```

`task demo` clones `demo/whoami` when it is missing and starts Claude Code
there. The session has its own empty config folder in `runtime/claude-config`.
Log in in the browser. Your own Claude Code setup stays untouched.

`glab` needs a token. Create it in the GitLab UI as `demo`, and put it in
`.env` in the clone (`runtime/clone/whoami/.env`) as `GITLAB_TOKEN` and
`GITLAB_HOST`. Never put the token in a prompt or a commit.

## Move around

| Command | What it does |
|---------|--------------|
| `task reset` | Brings GitLab, the servers and the demo profile back to the start |
| `task checkpoint -- <id>` | Jumps to a cut point of the session |
| `task status` | Shows the containers and the answers of GitLab |
| `task stop` | Stops the containers and keeps the data |
| `task terminate` | Deletes the containers, the volumes and `runtime/`. The root CA stays |

The checkpoint ids, in session order: `1a-app-written`, `1-end`,
`2a-json-written`, `2-end`, `3a-ui-written`, `3-end`.

## Prompts and slides

- `prompts/` has the prompts of the session, one file each.
- Open `slides/index.html` in a browser. `task slides` rebuilds
  `slides/prompts.js` from `prompts/`.

## Develop

- `task check` runs `shellcheck`, `shfmt` and `yamllint`.
- `task test` runs the tests that need no playground.
- `task test:live` runs the tests that need the running playground, then
  runs `task reset`.
