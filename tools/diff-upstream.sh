#!/bin/bash
set -euo pipefail

# Reconcile the vendored directives against TomBorglum/wsl-cloud-init, which maintains
# the terminal copies.
#
# Divergence is expected, not a failure of anything: extracting this repository traded a
# CI gate for a maintainer duty, deliberately. This script is that duty's tooling - run
# it when you have time to reconcile, not on every change.
#
# Usage: tools/diff-upstream.sh [path-to-wsl-cloud-init-checkout]
#
# Exits 0 when every copy matches, 1 when any differs, 2 when the checkout is unusable.

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="${1:-$HOME/projects/wsl-cloud-init}"

if [[ ! -d "$UPSTREAM/wsl/user/.config" ]]; then
  echo "diff-upstream: $UPSTREAM does not look like a wsl-cloud-init checkout" >&2
  echo "               (no wsl/user/.config). Pass the path as the first argument." >&2
  exit 2
fi

# here:upstream, relative to each repository root. Only the files that genuinely exist
# in both - env.sh and the settings.json template live here now and nowhere else, which
# the summary below states so their absence does not read as an oversight.
PAIRS=(
  "payload/direnv/lib/fnm.sh:wsl/user/.config/direnv/lib/fnm.sh"
  "payload/direnv/lib/pixi.sh:wsl/user/.config/direnv/lib/pixi.sh"
  "payload/direnv/lib/sdk.sh:wsl/user/.config/direnv/lib/sdk.sh"
  "payload/direnv/lib/claude/sonarqube.sh:wsl/user/.config/direnv/lib/claude/sonarqube.sh"
  "payload/pixi/templates/python.toml:wsl/user/.config/pixi/templates/python.toml"
)

echo "comparing $SRC against $UPSTREAM"
echo

differed=0
for pair in "${PAIRS[@]}"; do
  here="${pair%%:*}"
  there="${pair#*:}"
  if [[ ! -f "$UPSTREAM/$there" ]]; then
    echo "GONE     $here"
    echo "         upstream no longer has $there - it may have moved or been deleted."
    differed=1
    continue
  fi
  if diff -u "$UPSTREAM/$there" "$SRC/$here" > /tmp/diff-upstream.$$ 2>&1; then
    echo "same     $here"
  else
    echo "DIFFERS  $here"
    sed 's/^/         /' /tmp/diff-upstream.$$
    differed=1
  fi
  rm -f /tmp/diff-upstream.$$
done

echo
echo "Not vendored, owned here: payload/direnv/lib/claude/env.sh and"
echo "payload/claude/templates/settings.json. wsl-cloud-init does not carry them."

if (( differed )); then
  echo
  echo "Reconcile in whichever direction is right - upstream is not automatically"
  echo "correct, and a cloud-only fix belongs only here."
  exit 1
fi
