# Contributing

## What this repository is, and is not

It makes an environment **Claude cloud enabled**: it installs direnv, pixi and the
`use` directives an `.envrc` declares, so a Claude Code session has the project's
toolchain on `PATH`. Two targets, two entry points:

| Entry point | Target | How it runs |
| --- | --- | --- |
| `bootstrap.sh` | an Anthropic-hosted cloud VM | `curl \| bash` from the environment's setup-script field, as root, no arguments |
| `install.sh` | a workstation or WSL instance | cloned and run as your own user, no sudo |

It does **not** provision a WSL instance — that is
[`TomBorglum/wsl-cloud-init`](https://github.com/TomBorglum/wsl-cloud-init), which
installs the terminal copies of these directives as part of a full environment build.
This repository is the add-on that makes such an instance, or any other machine, able to
participate in the cloud workflow.

## Commits and releases

[Conventional Commits](https://www.conventionalcommits.org/), enforced by review rather
than by a linter. The **PR title** is what lands on `main` (squash merge), so it is the
subject release-please parses.

| Type | Release | Changelog |
| --- | --- | --- |
| `feat:` | minor | **Features** |
| `fix:` | patch | **Bug Fixes** |
| `deps:` | patch | **Dependencies** |
| `feat!:` / `BREAKING CHANGE:` | major | **Features**, flagged |
| `ci:` `docs:` `chore:` `refactor:` `test:` `style:` | none | hidden |

Releases are automated by [release-please](https://github.com/googleapis/release-please).
Merging a PR opens or updates a **chore(main): release X.Y.Z** PR; merging *that* tags
the release and publishes the notes. No manual tagging.

### Why the release matters more here than in a library

The setup script tracks `refs/tags/v1`, so **nothing reaches a cloud session until a
release is cut**. Three tags come out of each one:

| Pin | Moves? | Use when |
| --- | --- | --- |
| `@v1` | on every 1.x release | **the default** — what the documented setup script tracks |
| `@v1.2` | on every 1.2.x release | you want patches only |
| `@v1.2.3` | never | you need a reproducible environment and will bump it yourself |

`v1` and `v1.2` are deliberately mutable — that is how a fix reaches an environment
provisioned weeks ago, via `cloud-bootstrap-refresh`. Exact versions are immutable and
enforced as such by a repository ruleset.

A major bump means `v1` stops moving, so a breaking change can never arrive unannounced
in an environment whose setup script you have not edited.

## The exit-code contract

`bootstrap.sh` runs `cloud/scripts/*.sh` in order and reports each one by exit code, the
same contract `wsl-cloud-init`'s `install.sh` uses:

| Code | Meaning |
| --- | --- |
| `0` | did the work |
| `3` | already installed |
| `4` | not selected |
| other | failed |

A failure is **recorded and reported, never fatal**: `bootstrap.sh` always exits 0,
because a setup script that exits non-zero blocks the session from starting at all,
which is worse than a session whose environment is incomplete — there you can at least
ask Claude what went wrong. Each script's header says which codes it can return and why.

## Vendored from wsl-cloud-init

These files are **copies**, not the originals. They are maintained in
`wsl-cloud-init` for the terminal, and vendored here because a cloud session needs them
defined and this repository must not depend on that one:

| Here | Upstream |
| --- | --- |
| `payload/direnv/lib/fnm.sh` | `wsl/user/.config/direnv/lib/fnm.sh` |
| `payload/direnv/lib/pixi.sh` | `wsl/user/.config/direnv/lib/pixi.sh` |
| `payload/direnv/lib/sdk.sh` | `wsl/user/.config/direnv/lib/sdk.sh` |
| `payload/direnv/lib/claude/sonarqube.sh` | `wsl/user/.config/direnv/lib/claude/sonarqube.sh` |
| `payload/pixi/templates/python.toml` | `wsl/user/.config/pixi/templates/python.toml` |

`payload/direnv/lib/claude/env.sh` and `payload/claude/templates/settings.json` are
**not** vendored — they live here now, and `wsl-cloud-init` no longer carries them.

Divergence is expected and is nobody's bug: that is the point of the split. Reconcile
deliberately, when you have time for it:

```bash
tools/diff-upstream.sh ~/projects/wsl-cloud-init
```

Silence means the copies match. The same relationship exists between those directives
and `TomBorglum/actions/direnv/setup`, whose copies are deliberately *different* — a
CI-only implementation that scaffolds nothing. Do not reconcile towards those.

## Pinned versions Dependabot cannot see

Dependabot covers this repository's workflow actions and nothing else, because nothing
else here is a pin it can parse. Two versions therefore move by hand:

- **pixi** — `cloud/scripts/02-install-pixi.sh` pins `VERSION`, `BUILD` and `SHA256` as
  a triple from conda-forge. All three change together; find the new build and hash on
  [conda-forge/pixi](https://anaconda.org/conda-forge/pixi/files). `test/fixture-cloud/.envrc`
  pins the same version and must be bumped in the same commit — a cloud session cannot
  reach `pixi.sh` to install any other one, so a fixture that disagrees cannot pass.
  Commit as `deps:`.
- **direnv** — not pinned at all. It comes from the distribution's apt archive and floats
  with the image, deliberately: a cloud session's GitHub proxy scopes release-asset
  requests to repositories attached to the session, so `direnv/direnv` is unreachable.
  Both directives this repository ships touch only long-stable stdlib (`watch_file`,
  `PATH_add`), so the float is tolerable here in a way it is not in CI.

## Tests

Two workflows, both required by main-protection:

- **`cloud-bootstrap-test`** — runs `cloud/scripts/*` the way a session does: as root, in
  a bare `ubuntu:24.04` container, with the hosted image's blocked third-party apt
  sources reproduced. Asserts a fresh install, that a repeat run is a no-op (the common
  case, since a provisioned VM is replayed from a snapshot), that a never-`direnv
  allow`ed `.envrc` still loads, and that `use_claude_env` never writes inside a cloud
  session.
- **`claude-env-test`** — runs `install.sh` and then exercises `use_claude_env` the way a
  workstation does, with real direnv, real jq and real git repositories: a fresh
  repository gets the template verbatim, a reload changes nothing, an existing
  `settings.json` keeps its own keys and hooks, an unparseable one is left alone, and the
  file lands at the repository root.

Both assert *what a session would notice*, not implementation detail. A new install
script needs a case in the first; a change to `use_claude_env` needs one in the second.

## Shell conventions

Every script is bash and says why in its header — not what it does, which the code
shows, but why it does it that way: which failure it is avoiding, which observed
behaviour of a hosted VM it is working around. Those headers are the reason this
repository is maintainable at all; keep them current when you change the code under them.

`set -euo pipefail` everywhere except `bootstrap.sh` and the generated
`cloud-bootstrap-refresh`, both of which must survive their own failures and say so at
the top.

## Guardrails

`main` is protected by a repository ruleset: pull requests only, linear history, no
force-pushes or deletions, and the required SonarCloud and test checks — with no bypass
actors, including for maintainers. Version tags have their own ruleset making `v*.*.*`
immutable, which is what the `vX` / `vX.Y` moving tags are measured against.
