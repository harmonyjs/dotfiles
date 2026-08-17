# `remote` — ad-hoc test execution on a remote box — design

**Date:** 2026-08-17
**Status:** design approved in brainstorming; pending review gate
**Repo:** `bin/remote` + sweeper + this spec live in `dotfiles`; `compose.test.yaml` lands in each participating service repo.

## Goal

Run any ad-hoc command - a test suite, a one-off amplified property run, a
build - on a remote Linux box instead of the local Mac, against the working
tree as it is right now, uncommitted changes included. Output streams back to
the terminal so it feels like a local run.

The motivating case: hunting a flake in `activity-registry` with
`go test ./proptest/... -rapid.checks=2000`. That is a deliberate 20x over the
rapid default of 100 checks, it saturates every P-core for tens of minutes, and
it is exactly the kind of thing that should not run on the machine also
rendering the editor.

Ordinary CI is not the answer here and does not need to be: `ci.yml` already
runs both suites on every push in about 1.7 minutes. What CI structurally
cannot do is run a command that only exists in your head against a tree you
have not committed.

## What the repo survey changed

The design started from "put a compose file in each repo" and was talked out of
it, then back into it. Both moves came from evidence, so the evidence is
recorded here rather than lost.

A scan of all 44 repos under `mytonwallet-org` found:

- **Zero docker-compose files.** Nobody in the org uses compose. This was the
  first argument against making compose the contract - and it turned out to be
  an argument about habit, not fitness.
- **The Go side is uniform.** Five repos (`activity-registry`,
  `activity-contract`, `alchemy-gateway`, `codex-token-broker`,
  `zerion-gateway`), all on `go 1.26.3`, all driven by a `Justfile`, and all
  already carrying a recipe that starts their own sidecar: `pg-up`/`pg-down`,
  `db-up`/`db-down`, `valkey-up`/`valkey-down`.
- **Sidecars are almost all postgres:16.** The one exception is
  `alchemy-gateway`, which needs valkey.
- **Ports and env var names are deliberately not unified:** `PG_TEST_URL` on
  5433, `TEST_DATABASE_URL` on 55434, `TEST_DATABASE_URL` on 55432. Distinct
  ports so several repos can run locally at once.
- **The Node side is not uniform.** npm everywhere, but the node version is
  pinned in no repo at all - not `.nvmrc`, not `engines`. It exists only in CI
  (`node-version: 24`, `24.13.0`, `${{ vars.NODE_VERSION }}`). Test runners
  vary: jest, vitest, hand-rolled chains.

So a contract already exists de facto on the Go side - each repo knows how to
stand up its own environment - it is just spelled differently in each repo, and
it hardcodes a container name and a host port.

## Why compose is the contract

Leaning on the existing Justfile recipes would need no new files anywhere. It
was rejected because of what it cannot fix:

- `docker run --name ar-pg -p 5433:5432` means two branches of one repo cannot
  run at the same time. Name collision, port collision.
- The runner container would need the host docker socket mounted so `just
  pg-up` could start a sibling container. That is root-equivalent access to the
  host, granted to every ad-hoc command.
- Readiness is hand-rolled waiting.

A bespoke `.remote.yaml` was considered and dropped outright: everything it
would hold - image, sidecars, env, volumes - compose already expresses, better
and in a format people can look up. It would have been a worse compose.

Compose does not patch those three problems, it removes them:

- Services reach each other by service name on a private per-project network.
  **No host ports are published at all**, so a port collision between branches
  is not rare, it is unrepresentable.
- `-p <project>` isolates networks, volumes and containers per run, for free.
- `depends_on` + `healthcheck` replace the hand-rolled wait.
- Compose orchestrates from outside the runner, so **the runner needs no docker
  socket** and stays an ordinary unprivileged container.
- `compose down -v` is a teardown that actually removes the volumes.

Compose becomes the single description, used locally too. The local `pg-up` /
`db-up` / `valkey-up` recipes are rewritten to drive it, so there is one source
of truth rather than a local path and a remote path that drift.

## Architecture

| Component | Location | Responsibility |
|---|---|---|
| `bin/remote` | `dotfiles` | the client - everything below happens here |
| `compose.test.yaml` | each participating repo | the only description of the run environment |
| `remote-sweeper` | cron on the server | teardown that does not depend on a live client |
| `~/.config/remote/config` | local | server address, concurrency limit, default timeout |

The server runs nothing bespoke. Docker, rsync and cron. Anything that goes
wrong is diagnosable with `docker ps` and `docker compose ls`.

### Component 1 - the client

A standalone executable on `PATH`, not a Justfile recipe. The recipe form was
rejected because the same recipe would have to be copied into twenty Justfiles.

```
remote just itest
remote 'go test ./proptest/... -rapid.checks=2000'
remote --timeout 45m just test-all
remote --ls                 # what is running on the server
remote --attach <run-id>    # reattach to logs after a disconnect
remote --kill <run-id>
```

`~/.config/remote/config` holds `host` (required, no default - the tool refuses
to guess where to send work), `slots = 4`, `timeout = 30m`, `ttl = 2h` for the
sweeper, and the `pull` allowlist. `slots` and `timeout` are the two that keep
one box from being flooded the way the Mac was; both are deliberately small
enough to notice rather than generous enough to hide a runaway.

### Component 2 - the compose contract

Each participating repo carries `compose.test.yaml` with a `runner` service and
its sidecars. The source mount is a variable so the same file serves both the
local and the remote path:

```yaml
services:
  runner:
    image: golang:1.26.3
    working_dir: /src
    volumes:
      - ${REMOTE_SRC:-.}:/src
      - ar-gocache:/root/.cache/go-build
      - go-modcache:/go/pkg/mod
    environment:
      PG_TEST_URL: postgres://postgres:test@postgres:5432/activity_test?sslmode=disable
    depends_on:
      postgres: { condition: service_healthy }

  postgres:
    image: postgres:16
    environment: { POSTGRES_PASSWORD: test, POSTGRES_DB: activity_test }
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 2s
      retries: 15

volumes:
  ar-gocache: { external: true }
  go-modcache: { external: true }
```

The cache volumes are `external` on purpose, and it is easy to get wrong.
Compose namespaces the volumes it manages by project name, and the project name
here is per-run - so a plain volume entry would give every run a cold cache and
quietly defeat the point. Declaring them external pins them to fixed names
outside any project, which is what makes them shared. The client creates them on
first use.

`REMOTE_SRC` is the detail that makes one file serve both worlds. Compose reads
the file on the client but resolves bind paths against the **remote** daemon, so
the client exports `REMOTE_SRC=~/remote-runs/<run-id>/src`; unset, it falls back
to `.` and the file works unchanged for a local run.

Note the connection string points at `postgres:5432` - the service name on the
project network - not at a published host port. That is the whole isolation
argument in one line.

### Component 3 - the sweeper

A cron job on the server. It lists compose projects with the `rr-` prefix and
tears down any whose runner container has exited, or whose start label is older
than its TTL: `compose -p <project> down -v`, then remove
`~/remote-runs/<run-id>`.

This is the same shape as the local `reap-orphan-shells.sh` hook, for the same
reason: teardown must not depend on a client being alive to perform it.

## Run lifecycle

1. **Derive the run id:** `rr-<repo>-<branch>-<short hash of worktree path>`,
   which is also the compose project name. Deterministic, so a repeated run from
   the same branch reuses its directory and its warm caches.
2. **Take a slot.** `flock` against one of N slot files on the server. Over the
   limit, wait and say so; never hang silently.
3. **Sync.** rsync the tree to `~/remote-runs/<run-id>/src`, filtered by
   `.gitignore`, without `.git`. First run copies everything, later runs only the
   delta.
4. **Bring up sidecars.** `compose -p <run-id> up -d`, with `healthcheck`
   gating readiness.
5. **Start the runner detached** and capture its container id:
   `compose -p <run-id> run --detach runner timeout <N> sh -c '<command>'`.
6. **Stream.** `docker logs -f <cid>` in the foreground. This is what
   `--attach` re-runs later.
7. **Collect and tear down** on clean exit: pull artifacts back, then
   `compose -p <run-id> down -v`.

### Why the timeout lives inside the container

`timeout(1)` wraps the command as the container's own process. It is not a
client-side watchdog and not a server-side daemon, so it keeps ticking through a
dropped ssh connection, a closed laptop, or a killed Claude session. Nothing has
to stay alive to enforce it.

This is a direct response to the incident that prompted the whole tool: a Claude
session ran a repro that spawned 36 busy-loop shells, died before its cleanup
line, and left them burning all 18 cores for 44 minutes. Locally that announced
itself through the fan. On a remote box nobody would have heard it. The rule
Andrey chose is that a run **survives a disconnect but always carries a hard
deadline**, and the deadline is unconditional.

Detached start plus `logs -f` is what makes that survival real: an attached
`compose run` would tie the container's lifetime to the client's terminal.

### Artifact return never overwrites source

Only an allowlist comes back - never the tree. A blanket reverse sync would
clobber edits made locally while the run was in flight. The default list is
`**/testdata/rapid/**`, `coverage.out` and `artifacts/`; `--pull <path>` adds to
it for a single run, and `pull` in `~/.config/remote/config` overrides the
default globally.

When a run fails, the rapid failfile carrying the reproducing seed is the single
most valuable thing it produced, so **artifacts are collected on failure too**,
not only on success.

## Isolation

- Compose project name per run isolates network, volumes and containers.
- No host ports published, ever. Sidecars are reachable only inside the project
  network.
- One directory per run under `~/remote-runs/`.
- **Caches are shared, not per run** - build caches per repo
  (`<repo>-gocache`, `<repo>-npmcache`), the Go module cache global
  (`go-modcache`), all as external volumes as described above. Per-run caches
  would make every branch compile from scratch and defeat the point. Both the Go
  build cache and the module cache are safe under concurrent access by design.

## Error handling

| Situation | Behaviour |
|---|---|
| Server unreachable | Say so plainly, suggest the local run |
| No `compose.test.yaml` | Print the template to create, not `file not found` |
| Concurrency limit reached | Show `--ls` output and wait; never hang mutely |
| Timeout fired | Distinct exit code, explicit "killed after N" line, not a bare SIGKILL |
| Command failed | Artifacts still collected, project still torn down |

`timeout(1)` exits 124 on expiry; the client maps that to its own message rather
than passing a confusing status upward.

## Repo migration

The five Go repos each get a `compose.test.yaml`, and their `pg-up` / `db-up` /
`valkey-up` recipes are rewritten to drive compose. Their connection strings move
from a published host port to a service name. Local and remote then behave
identically because they read the same file.

`activity-registry`'s `itest` keeps `-p 1`: that flag is not about host ports,
it is because the integration packages share one Postgres and TRUNCATE fixture
tables mid-run. Compose does not change that constraint.

Node repos join by adding the same file, with no change to the tool - compose is
language-agnostic. They are a separate wave: there are fifteen of them, their
node version is pinned nowhere in-tree, and pinning it is a decision to make
per repo rather than guess.

## Testing

- **Unit,** in the style of the existing `*.test.sh` hooks in `dotfiles`:
  argument parsing, run-id derivation, rsync filter construction.
- **Integration:** point the client at a local docker daemon acting as the
  server and drive an end-to-end run against a fixture repo.
- **Negative cases,** each pinning an invariant rather than a happy path: ssh
  dropped mid-run leaves the container alive; an expired timeout kills it; the
  sweeper reclaims a project whose client never came back.

## Out of scope

A server pool, a scheduler, a web UI, per-run CPU and memory quotas. One box,
one user plus their agents, a slot limit and a deadline.

## Requires from the server

Linux with docker, ssh key auth for the account, and the account in the `docker`
group. No language toolchains: they arrive as images, so their versions follow
each repo rather than drifting on the host.
