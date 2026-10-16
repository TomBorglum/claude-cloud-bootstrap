#!/bin/bash
set -euo pipefail

# The workstation add-on: makes an environment you already use "Claude cloud enabled".
#
# What that means concretely is one directive and the template it scaffolds from. A
# machine provisioned by TomBorglum/wsl-cloud-init already has direnv and the
# use_fnm / use_pixi / use_sdk directives; what it cannot do is write the
# .claude/settings.json a cloud session needs, because that directive lived here from
# the start. Installing the runtime directives again would put a second owner on files
# wsl-cloud-init's 13-install-direnv-functions.sh maintains, which is the drift this
# split exists to avoid - so this deliberately installs neither them nor pixi.
#
# Unlike cloud/scripts/*, this is an entry point rather than a step in a run: it is
# invoked as ./install.sh, so it is mode 0755 rather than the 0644 those carry, and it
# does not speak the 0/3/4 exit-code contract - nothing is reading it. 0 means the
# payload is in place, non-zero means it is not.
#
# No already-installed guard, matching cloud/scripts/03-install-direnv-functions.sh:
# this is configuration to keep in sync rather than a payload to install once, and
# install(1) overwrites cleanly, so re-running is how a change to the directive reaches
# a machine that already has the old one.

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Per-user by design - everything below lands under $HOME and nothing needs root. Run
# under sudo and $HOME is root's, which puts the payload where direnv will never look
# while appearing to succeed, so refuse rather than install into the wrong home.
if [[ $EUID -eq 0 ]]; then
  echo "install.sh: run this as your own user, not as root or under sudo." >&2
  echo "            Everything it installs lives in \$HOME and needs no privileges." >&2
  exit 1
fi

# Both are prerequisites of the directive rather than of this script, so they warn and
# carry on: installing the payload is still the right outcome on a machine where direnv
# is about to be installed, and a half-done install is harder to reason about than a
# complete one with a clear warning.
if ! command -v direnv >/dev/null 2>&1; then
  echo "install.sh: warning - direnv is not on PATH. The directive installs fine, but" >&2
  echo "            nothing will evaluate it until direnv is installed and hooked into" >&2
  echo "            your shell (eval \"\$(direnv hook zsh)\")." >&2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "install.sh: warning - jq is not on PATH. use_claude_env needs it to merge into" >&2
  echo "            a repository's existing .claude/settings.json; without it the" >&2
  echo "            directive warns and leaves the file alone." >&2
fi

# Flat into ~/.config/direnv/lib, not into a claude/ subdirectory: direnv globs that
# directory non-recursively, so a file left in a subdirectory is silently never defined.
# The destination basename is env.sh because that is what wsl-cloud-init installed this
# same file as, so on an instance it provisioned this overwrites rather than leaving two
# definitions of use_claude_env to race.
LIB_DST="$HOME/.config/direnv/lib"
install -d "$LIB_DST"
install -m 644 "$SRC/payload/direnv/lib/claude/env.sh" "$LIB_DST/env.sh"

# use_claude_env reads this path literally ($HOME/.config/claude/templates/settings.json)
# and warns rather than scaffolding when it is missing.
TPL_DST="$HOME/.config/claude/templates"
install -d "$TPL_DST"
install -m 644 "$SRC/payload/claude/templates/settings.json" "$TPL_DST/settings.json"

echo "installed use_claude_env to $LIB_DST/env.sh"
echo "installed the settings.json template to $TPL_DST/settings.json"
echo
echo "Next, in a repository you want a cloud session to work in:"
echo "  echo 'use claude_env' >> .envrc && direnv allow"
echo "then commit the .claude/settings.json it writes - only a committed copy reaches a"
echo "cloud session."
