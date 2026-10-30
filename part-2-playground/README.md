# Part 2: a playground for one repository

A local GitLab, a runner, a Traefik proxy and two small servers (`test` and
`prod`). In the session, Claude Code builds a small app, `whoami`, and ships
it through a pipeline from `test` to `prod`. All of it runs in Docker on
your Mac.

## Requirements

- A Mac on Apple silicon, with Docker Desktop running
- `task`, `openssl`, `jq`, `git`, `curl`, `ssh` and `ssh-keygen`
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
session. It also lists the checks that need you.

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
there. The demo lives in `~/llm-praxis-demo` (`PG_DEMO_HOME` changes the
folder): the clone `whoami/`, the config folder `claude-config/` and a copy
of the SSH config in `ssh/`. It lives outside this repository on purpose, so
that Claude Code loads no parent `CLAUDE.md` or `.mcp.json`. `task demo` and
`task preflight` refuse to run when a parent folder has one. Log in in the
browser. Your own Claude Code setup stays untouched.

### Make the GitLab token

`glab` needs a token. Make it in the GitLab UI, in step 9 of the session:

1. Sign in at <https://gitlab.playground.localhost> as `demo`.
2. Open
   <https://gitlab.playground.localhost/-/user_settings/personal_access_tokens>.
3. Select **Generate token**, then **Legacy token**.
4. Type a name, such as `glab demo`. Set the expiration date to tomorrow.
5. Select the `api` scope, then **Generate token**.
6. Select the copy button next to the token. GitLab shows the token only
   one time.
7. In a terminal, write the token from the clipboard to the
   `.env` of the clone:

   ```shell
   (umask 077; printf 'GITLAB_TOKEN=%s\nGITLAB_HOST=gitlab.playground.localhost\n' "$(pbpaste)" > ~/llm-praxis-demo/whoami/.env)
   ```

8. Check the token. This command prints `demo`:

   ```shell
   (set -a; . ~/llm-praxis-demo/whoami/.env; glab api user | jq -r .username)
   ```

The clone ignores `.env` in git, and the demo session cannot read it. A
hook of the session loads it before each command, so a running session
can use `glab` at once. Never put the token in a prompt or a commit.
`task reset` revokes the token.

## Move around

| Command | What it does |
|---------|--------------|
| `task reset` | Brings GitLab, the servers and the demo profile back to the start |
| `task checkpoint -- <id>` | Jumps to a cut point of the session |
| `task status` | Shows the containers and the answers of GitLab |
| `task stop` | Stops the containers and keeps the data |
| `task terminate` | Deletes the containers, the volumes the demo folder and `runtime/`. The root CA stays |

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
