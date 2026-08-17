# `remote` — ad-hoc test execution on a remote box — design

**Date:** 2026-08-17
**Status:** design approved in brainstorming; mechanical findings from
adversarial review applied; three architectural questions still open (see Open
questions)
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
    profiles: [runner]        # never started by `compose up`; see below
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

`runner` sits behind a `runner` profile so that `compose up` starts sidecars
only. Without the profile, `up` starts every declared service - including a
`runner` that nothing is waiting on - and then `compose run` creates a second
one. Two containers of the same service, one of them idle, is enough to make any
"has the runner exited" check on the sweeper side answer the wrong question.

`REMOTE_SRC` is the detail that makes one file serve both worlds, and it must be
an **absolute path on the server, expanded before compose ever sees it**.
Compose reads the file on the client but resolves bind paths against the remote
daemon, and a `~` in the value is expanded by the client shell against the
client's `$HOME` - which on a Mac client yields `/Users/<user>/remote-runs/...`,
a path that does not exist on a Linux daemon. So the client resolves the server
home once (`ssh <host> 'echo $HOME'`, cached in the run metadata) and exports a
fully-expanded `REMOTE_SRC=/home/<user>/remote-runs/<run-id>/src`. Unset, it
falls back to `.` and the file works unchanged for a local run.

Note the connection string points at `postgres:5432` - the service name on the
project network - not at a published host port. That is the whole isolation
argument in one line.

### Canonical compose invocation

Every compose call - client and sweeper alike - passes the file and the project
explicitly:

```
docker compose -f <server-run-dir>/src/compose.test.yaml -p <run-id> <cmd>
```

Compose's default file discovery looks for `compose.yaml` or
`docker-compose.yaml` in the working directory, so a contract named
`compose.test.yaml` is invisible without `-f`. The sweeper runs from cron with
no meaningful working directory at all, which makes this less a style preference
than the difference between a teardown that works and one that silently finds no
project. The absolute path is written into the run metadata at submit time and
read back from there by everything downstream.

### Component 3 - the sweeper

A cron job on the server. For each run directory it reads the run metadata -
compose file path, job container id, start time, TTL - and tears the project
down when the recorded **job container** has reached a terminal state, or when
the TTL has expired: `compose -f <recorded path> -p <project> down -v`, then
remove the run directory.

It keys on the recorded container id rather than on "a container of service
`runner`". Service identity is ambiguous by construction here, because
`compose run` creates one-off containers of the same service; the id captured at
submit time is the only unambiguous handle on the job this run is actually
about.

This is the same shape as the local `reap-orphan-shells.sh` hook, for the same
reason: teardown must not depend on a client being alive to perform it.

## Run lifecycle

1. **Derive the run id:** `rr-<repo>-<branch>-<short hash of worktree path>`,
   which is also the compose project name. Deterministic, so a repeated run from
   the same branch reuses its directory and its warm caches.
2. **Take a slot.** `flock` against one of N slot files on the server. Over the
   limit, wait and say so; never hang silently.
3. **Sync.** rsync the tree to `<server home>/remote-runs/<run-id>/src` -
   the server's home, resolved server-side, never the client's - filtered by
   `.gitignore`, without `.git`. First run copies everything, later runs only the
   delta.
4. **Bring up sidecars.** `compose up -d` with the canonical invocation. The
   `runner` profile keeps the runner out of it, so this starts sidecars only,
   with `healthcheck` gating readiness.
5. **Start the job detached** and record its container id in the run metadata:
   `compose run --detach runner timeout --kill-after=30s <N> sh -c '<command>'`.
6. **Stream.** `docker logs -f <cid>` in the foreground. This is what
   `--attach` re-runs later.
7. **Get the terminal status** from `docker wait <cid>`, not from the log
   follower - `logs -f` returns when the stream closes and tells you nothing
   about how the process ended.
8. **Collect and tear down** on clean exit: pull artifacts back, then
   `compose down -v` with the canonical invocation, and remove the run
   directory.

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

`--kill-after=30s` is what makes "unconditional" true rather than aspirational.
Bare `timeout` sends TERM and then waits forever; a process that ignores TERM -
a Go test binary mid-syscall, a shell that traps it - outlives the deadline it
was supposed to be bounded by. The escalation to KILL is the whole guarantee.

The escalation is worth stating as an invariant to test rather than a flag to
remember: a command that ignores TERM must still be gone within
`timeout + kill-after`.

### Artifact return never touches the working tree

Results land in a run-scoped directory outside the worktree -
`~/.local/state/remote/<run-id>/` - and the client prints the path. Nothing is
ever written back into the source tree.

An allowlist alone was not enough to make the earlier "never overwrites source"
claim true: the defaults are source-relative paths like `coverage.out` and
`artifacts/`, so a locally-edited `artifacts/foo` would have been overwritten by
the return of a run that started before the edit. Writing outside the tree is
what actually delivers the invariant; the allowlist only decides what is worth
carrying back. Copying anything into the tree stays a separate, explicit act by
whoever wants it there.

The allowlist defaults to `**/testdata/rapid/**`, `coverage.out` and
`artifacts/`, interpreted **relative to the run's source root on the server**.
Absolute paths, `..` traversal and symlinks pointing outside that root are
rejected rather than followed - a rule that matters precisely because the
patterns can be extended per run with `--pull <path>`, and `pull` in
`~/.config/remote/config` replaces the defaults globally.

When a run fails, the rapid failfile carrying the reproducing seed is the single
most valuable thing it produced, so **artifacts are collected on failure too**,
not only on success.

## Isolation

- Compose project name per run isolates network, volumes and containers.
- No host ports published, ever. Sidecars are reachable only inside the project
  network.
- One directory per run under `<server home>/remote-runs/`.
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

The status comes from `docker wait` on the recorded container id. `timeout(1)`
exits 124 on expiry and 137 when it had to escalate to KILL; the client maps
both to its own message rather than passing a confusing number upward, and keeps
them distinguishable from an ordinary non-zero test failure. A test suite that
legitimately exits 124 is not a case worth designing around, but the run
metadata records that the deadline fired, so the two are told apart by recorded
fact rather than by guessing from the code.

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
- **Negative cases,** each pinning an invariant rather than a happy path:
  - ssh dropped mid-run leaves the container alive, and `--attach` finds it
    again along with its artifacts;
  - a command that traps and ignores TERM is still gone within
    `timeout + kill-after`;
  - the sweeper reclaims a project whose client never came back, and does not
    reclaim one whose job is still running;
  - a locally-modified file at an allowlisted artifact path is untouched after a
    run returns;
  - `docker compose config` against the remote context resolves the bind source
    to a path that exists on the server. This one is worth a test rather than a
    read-through: the failure mode is a `~` silently expanding on the wrong
    machine, which reads as correct in the file and only shows up at mount time.

## Open questions

An adversarial review raised three things that are decisions rather than
defects. They are recorded here unresolved rather than papered over, because
each one trades away something the design deliberately chose.

**Run id is deterministic, and two runs from one worktree collide.** The id is
`<repo>-<branch>-<hash of worktree path>` precisely so a repeat run reuses its
directory and its warm caches. The cost is that two concurrent runs from the
same branch share a source directory, share sidecars and a database, and the
first one to finish tears down the other with `down -v`. A unique id per
execution removes the collision and gives up cheap incremental rsync and warm
per-run state; a worktree mutex keeps both but makes the second run wait. Which
is right depends on whether concurrent runs from one branch are a real workflow
or an accident worth refusing outright.

**Slots and retention live in client config, with no server-resident owner.**
A `flock` held by the submitting client is released when that client dies, while
its detached run keeps going - so the next submit can exceed the limit. And the
sweeper tearing down promptly on exit means a disconnected client loses the logs
and artifacts it never got to pull. Fixing both properly means server-owned run
state: a lease held until verified terminal cleanup, and a retention window
before reclamation. That is a step back toward the job daemon that was
deliberately rejected, so it is a scope decision, not a bug fix.

**The compose file arrives from an uncommitted tree and is executed by a daemon
running as an account in the `docker` group.** Keeping the socket out of the
runner does not constrain what the compose file itself may ask for -
`privileged`, host networking, a bind mount of the host root. Either the box is
treated as disposable and fully trusted to whatever the local agents produce, or
the server accepts only reviewed profiles rather than client-supplied compose.
This needs an explicit answer before the tool runs anything on a machine that
matters.

## Out of scope

A server pool, a scheduler, a web UI, per-run CPU and memory quotas. One box,
one user plus their agents, a slot limit and a deadline.

## Requires from the server

Linux with docker, ssh key auth for the account, and the account in the `docker`
group. No language toolchains: they arrive as images, so their versions follow
each repo rather than drifting on the host.
