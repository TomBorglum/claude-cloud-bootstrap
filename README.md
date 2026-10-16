# claude-cloud-bootstrap

Make an environment **Claude cloud enabled** — direnv, pixi and the `use` directives a
project's `.envrc` declares, installed so that Claude Code works with the project's own
toolchain on `PATH`.

## Why anything is needed

Claude Code never evaluates an `.envrc` itself. On a workstation it works by
inheritance: `~/.zshrc` runs `eval "$(direnv hook zsh)"`, so a `claude` started from
inside a project inherits an environment direnv has already applied. Start a **cloud
session** — the ephemeral VMs behind the phone and desktop apps, `claude --cloud`, and
routines — and there is no parent shell at all, no direnv, and none of the `.envrc` in
effect. The runtimes it declares are simply absent.

Fixing that takes two halves, and this repository is the first:

1. **The environment** needs direnv, pixi and the directives installed. That is
   `bootstrap.sh` in a cloud session, or `install.sh` on your own machine.
2. **The repository** needs a committed `.claude/settings.json` whose hooks run
   `direnv export bash` into `$CLAUDE_ENV_FILE`. You do not write it by hand — the
   `use claude_env` directive scaffolds it.

## Cloud sessions

Paste this into the **Setup script** field of your cloud environment at
[claude.ai/code](https://claude.ai/code) (the environment selector above the message
box). It is the only piece that cannot live in a repository, which is why it is three
lines that delegate:

```bash
#!/bin/bash
curl -fsSL --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/TomBorglum/claude-cloud-bootstrap/refs/tags/v1/bootstrap.sh | bash
```

Leave the environment on the default **Trusted** network access. The bootstrap
deliberately takes direnv from apt and pixi from conda-forge — both already on the
default allowlist — rather than from `pixi.sh` or a GitHub release asset, which a cloud
session's proxy blocks.

`refs/tags/v1` moves on every 1.x release, so a fix reaches you without this field being
edited. See [Versioning](#versioning-and-pinning).

### Staying current

A cloud environment runs its setup script once, then snapshots the filesystem and
replays that snapshot for later sessions, skipping the script entirely. It re-runs only
when the setup script's text changes, when the allowed hosts change, or when the
snapshot expires after roughly seven days — none of which involves this repository.

So the bootstrap installs `cloud-bootstrap-refresh`, which a repository's `SessionStart`
hook calls. It compares the tracked ref's current tarball against the one this VM was
built from and re-runs the bootstrap if they differ. The command exists only where the
bootstrap installed it, which is what scopes it to cloud sessions without the hook
needing an environment check.

## Workstation and WSL instances

Making your own machine Claude cloud enabled is an add-on:

```bash
git clone https://github.com/TomBorglum/claude-cloud-bootstrap
cd claude-cloud-bootstrap && ./install.sh
```

It installs two files into your home directory and needs no root:

- the `use_claude_env` directive, into `~/.config/direnv/lib/`
- the `settings.json` template it scaffolds from, into `~/.config/claude/templates/`

That is deliberately all. An instance provisioned by
[`TomBorglum/wsl-cloud-init`](https://github.com/TomBorglum/wsl-cloud-init) already has
direnv and the `use fnm` / `use pixi` / `use sdk` directives; re-installing them here
would put two owners on the same files. What it lacks is the ability to *scaffold and
commit* the settings file a cloud session needs — which is exactly what this adds.

## The one file a repository needs

Add the directive, and direnv writes the file on the next load:

```bash
echo 'use claude_env' >> .envrc && direnv allow
```

It lands at the **repository root**, because that is the only place Claude Code reads
`.claude/settings.json` from — so an `.envrc` in a monorepo subdirectory still writes to
the root. If the repository already has one, the directive merges in only the hook
entries that are missing and leaves every other key alone; once they are there it is a
no-op, so it never dirties a working tree twice. **Commit the result** — only a committed
copy reaches a cloud session.

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [
        { "type": "command",
          "command": "command -v cloud-bootstrap-refresh >/dev/null 2>&1 && cloud-bootstrap-refresh || true" },
        { "type": "command",
          "command": "command -v direnv >/dev/null 2>&1 && direnv export bash >> \"$CLAUDE_ENV_FILE\" || true" }
      ] }
    ],
    "CwdChanged": [
      { "hooks": [
        { "type": "command",
          "command": "command -v direnv >/dev/null 2>&1 && direnv export bash >> \"$CLAUDE_ENV_FILE\" || true" }
      ] }
    ]
  }
}
```

Both commands are guarded on the tool existing, so the file is inert on a workstation:
there `direnv export` emits nothing, because direnv has already loaded the environment
the shell that launched `claude` passed in.

`use claude_env` never writes inside a cloud session — it only reports, on stderr, when
the clone is missing the file. Claude Code reads the hooks before direnv has run, so a
write there could not take effect until the next session, and would show up as an
untracked change in the session's diff.

## What the cloud bootstrap installs

| | |
| --- | --- |
| **direnv** | from apt, so it needs no allowlist change. Floats with the distro. |
| **pixi** | pinned by version, build and sha256 from conda-forge, pre-seeded into the version store `use pixi` resolves from, so the directive needs no change and installs nothing itself |
| **directives** | `use fnm`, `use pixi`, `use sdk`, `use sonarqube_mcp`, `use claude_env` |
| **pixi templates** | what `use pixi <version> <template>` scaffolds a missing `pixi.toml` from |
| **`direnv.toml`** | whitelisting the clone roots, so a fresh checkout is trusted the moment it lands and no `direnv allow` is needed |
| **`cloud-bootstrap-refresh`** | the command that makes a released fix reach an already-snapshotted VM |

No `direnv allow` in a cloud session is a deliberate trade, made only there: Claude
already has an unrestricted shell on a disposable single-tenant VM holding your own
repository, so `direnv allow` is friction rather than a boundary. `install.sh` makes no
such trade on a workstation. See [SECURITY.md](SECURITY.md).

## Versioning and pinning

Releases are automated from [Conventional Commits](https://www.conventionalcommits.org/)
by [release-please](https://github.com/googleapis/release-please). Each release produces
three tags:

| Pin | Moves? | Use when |
| --- | --- | --- |
| `refs/tags/v1` | on every 1.x release | **the default** — fixes and features with no edit to your setup script |
| `refs/tags/v1.2` | on every 1.2.x release | you want patches only |
| `refs/tags/v1.2.3` | never | you need a reproducible environment and will bump it yourself |

`v1` and `v1.2` are deliberately mutable — that is how a fix reaches an environment
provisioned weeks ago. Exact versions are immutable and enforced as such by a repository
ruleset. A major bump means `v1` stops moving, so a breaking change can never arrive
unannounced.

To track something else, set `CLOUD_BOOTSTRAP_REF` to a full ref path — for example
`refs/heads/main` to test an unreleased change:

```bash
#!/bin/bash
curl -fsSL --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/TomBorglum/claude-cloud-bootstrap/refs/heads/main/bootstrap.sh \
  | CLOUD_BOOTSTRAP_REF=refs/heads/main bash
```

Both halves need it: the URL decides which `bootstrap.sh` runs, the variable decides
which tarball it installs from, and leaving them to disagree is how you get a script
from one ref installing the scripts of another.

See the [changelog](CHANGELOG.md) for what each release contained.

## When the environment is wrong

The setup script's output is not surfaced anywhere a session can read, so the bootstrap
keeps a log on disk. The snapshot captures it, so it survives into later sessions and is
the first thing to look at:

```bash
cat /var/log/cloud-bootstrap.log     # every script and what it did
cat /var/lib/cloud-bootstrap/failed  # present only if something failed
```

A bare `PATH` with no error at all usually means direnv declined to load the `.envrc`
because the clone root is not whitelisted. `CLOUD_DIRENV_PREFIXES` (colon-separated)
overrides the defaults.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) — the exit-code contract, which commit types cut
releases, the files vendored from `wsl-cloud-init` and how to reconcile them, and the
pinned versions Dependabot cannot see.

## License

[MIT](LICENSE)
