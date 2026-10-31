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
task playground:start
```

- The first run makes the root CA in `~/.config/playgrounds/tls`. All
  playgrounds share this CA, and no script replaces it.
- If macOS does not trust the CA yet, macOS asks once for your admin
  password (`sudo security add-trusted-cert`). Later runs ask nothing.
- GitLab needs about 2 minutes to start.
- `task playground:start` ends when GitLab, the runner, the `demo/whoami` project and
  the two servers are ready.

Then prove the playground:

```shell
task playground:smoke
```

`task playground:smoke` deploys a small smoke app four times and empties the servers
afterwards. Run `task playground:preflight` before each rehearsal and before the
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
task claude:start
```

`task claude:start` clones `demo/whoami` when it is missing and starts Claude
Code there. `task claude:continue` continues the last conversation. Pass other
flags after `--`: `task claude:start -- -r` picks an older conversation. The demo lives in `~/llm-praxis-demo` (`PG_DEMO_HOME` changes the
folder): the clone `whoami/`, the config folder `claude-config/` and a copy
of the SSH config in `ssh/`. It lives outside this repository on purpose, so
that Claude Code loads no parent `CLAUDE.md` or `.mcp.json`. `task claude:start`
and `task playground:preflight` refuse to run when a parent folder has one. Log in in the
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
7. In a terminal (steps 7 and 8 use `~/llm-praxis-demo`; change the path when
   you set `PG_DEMO_HOME`), write the token from the clipboard to the
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
`task playground:reset` revokes the token.

## Move around

| Command | What it does |
|---------|--------------|
| `task playground:reset` | Brings GitLab, the servers and the demo profile back to the start |
| `task playground:status` | Shows the containers and the answers of GitLab |
| `task playground:stop` | Stops the containers and keeps the data. `task playground:start` resumes them |
| `task playground:terminate` | Deletes at once the containers, the volumes, the demo folder and `runtime/`. The root CA stays |

## Prompts and slides

- `prompts/` has the prompts of the session, one file each.
- `task slides:open` builds the deck and opens it in the browser.
- `task slides:build` rebuilds `slides/prompts.js` from `prompts/`.

## Develop

- `task dev:check` runs `shellcheck`, `shfmt` and `yamllint`.
- `task dev:test` runs the tests that need no playground.
- `task dev:test-live` resets the playground, runs the tests that need it, then
  runs `task playground:reset`.
