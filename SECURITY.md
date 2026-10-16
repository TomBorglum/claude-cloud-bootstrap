# Security Policy

## Supported Versions

Fixes land on `main` and reach consumers through the next release; please reproduce
against the latest commit on `main` before reporting an issue.

The moving `vX` and `vX.Y` tags are repointed on every release, so an environment whose
setup script tracks `refs/tags/v1` picks up a fix on its next bootstrap. An exact
`vX.Y.Z` tag or a commit SHA is immutable by design and is **not** backpatched — a fix
ships in the next release, and tracking that precisely means taking on the job of
bumping it.

## Reporting a Vulnerability

Please **do not** open a public issue for security vulnerabilities.

Instead, report privately via GitHub's
[private vulnerability reporting](https://github.com/TomBorglum/claude-cloud-bootstrap/security/advisories/new)
(the **Security → Report a vulnerability** button on the repository). This keeps the
report confidential until a fix is available.

When reporting, please include:

- A description of the vulnerability and its impact.
- Steps to reproduce, or a proof of concept.
- The affected script(s) and the commit or tag you observed it on.

You can expect an acknowledgement within a few days. Once confirmed, a fix will be
prepared and a GitHub Security Advisory published crediting the reporter (unless you
prefer to remain anonymous).

## Scope & Notes

`bootstrap.sh` runs **as root**, before Claude Code starts, on a VM holding the user's
repositories. That raises the stakes on what it fetches and how it verifies it, and all
of the following is in scope:

- **What is fetched, and from where.** The repository tarball comes from
  `codeload.github.com` over HTTPS with `--proto '=https' --tlsv1.2`, pixi from
  `conda.anaconda.org` pinned by version, build **and** sha256, which is checked before
  anything is extracted. direnv comes from the distribution's own signed apt archive.
  Issues in how this project fetches, verifies or executes any of these are in scope;
  compromise of an upstream source itself is outside this project's control.
- **The tarball's sha256 is change detection, not authentication.** It is recorded so
  `cloud-bootstrap-refresh` can tell that the tracked ref has moved. It is computed from
  what was just downloaded, so it proves nothing about origin — the HTTPS connection to
  codeload is what does that. A report that the recorded hash could be substituted along
  with the tarball it describes is in scope only if the transport can also be subverted.
- **What the installed scripts write, and as whom.** Everything the cloud path installs
  lands under `$CLOUD_HOME` or `/usr/local/bin`, is handed to the session account, and is
  listed in the log at `/var/log/cloud-bootstrap.log`.

Two deliberate design decisions are **not** vulnerabilities, and a report that they
behave as documented is out of scope:

- **A `curl | bash` entry point.** The cloud environment dialog offers a setup-script
  field and nothing else; a script fetched at run time is the only shape available
  there. The mitigation is that the field delegates in three lines to a ref you control,
  so what runs is reviewable at a tag rather than pasted and forgotten.
- **The direnv whitelist in a cloud session.** `cloud/scripts/03-install-direnv-functions.sh`
  writes a `direnv.toml` whitelisting the clone roots, so an `.envrc` loads without
  `direnv allow`. That trade is made **only** in a cloud session, where Claude already
  has an unrestricted shell on a disposable single-tenant VM holding the user's own
  repository, and the script's header states the reasoning. `install.sh` writes no
  `direnv.toml` and makes no such trade on a workstation; a change that extended it
  there *would* be a vulnerability.

The moving `vX` / `vX.Y` tags are mutable **on purpose** — that is the published
contract, and it is what lets a fix reach an already-provisioned environment. A report
that these tags can change is not in scope; pin an exact `vX.Y.Z` if you need
immutability, and accept that you are then the one who bumps it.
