#!/usr/bin/env bash
#
# Apply freshly-generated starter-kit output over a checked-out kit repo.
#
# Model: "generator wins by overwrite; the keep-list is the sanctioned exception."
# The whole tree is synced with --delete, so files the generator no longer emits
# are removed and the kit stays a faithful output — EXCEPT:
#
#   1. Anything .gitignore'd. The generated app's .gitignore (itself generator-owned
#      and synced) defines what is "not source": node_modules, tmp/log/storage junk,
#      vite/SSR build output, bundler config, env files, keys. rsync's dir-merge
#      filter reads it on both sides, so ignored junk is neither copied nor deleted.
#      (rsync treats gitignore's `!/log/.keep` re-includes as literal patterns —
#      harmless here: the .keep files exist identically on both sides anyway.)
#   2. The explicit keep-list below — tracked kit content that must survive.
#
# Usage: bin/sync_apply.sh <generated-app-dir> <kit-clone-dir> <kit-name>
set -euo pipefail

SRC="${1:?usage: sync_apply.sh <generated-app-dir> <kit-clone-dir> <kit-name>}"
DEST="${2:?usage: sync_apply.sh <generated-app-dir> <kit-clone-dir> <kit-name>}"
KIT="${3:?usage: sync_apply.sh <generated-app-dir> <kit-clone-dir> <kit-name>}"

# The .gitignore dir-merge filter needs real rsync 3.x. macOS ships openrsync,
# which silently misapplies it (junk copied, tracked files skipped) — refuse it.
RSYNC="${RSYNC:-rsync}"
if "$RSYNC" --version 2>/dev/null | head -1 | grep -qi openrsync; then
  for candidate in /opt/homebrew/bin/rsync /usr/local/bin/rsync; do
    if [ -x "$candidate" ] && ! "$candidate" --version 2>/dev/null | head -1 | grep -qi openrsync; then
      RSYNC="$candidate"
      break
    fi
  done
  if "$RSYNC" --version 2>/dev/null | head -1 | grep -qi openrsync; then
    echo "error: rsync 3.x required (--filter dir-merge); macOS openrsync won't work." >&2
    echo "       brew install rsync, or set RSYNC=/path/to/rsync." >&2
    exit 1
  fi
fi

# All patterns are anchored to the app root (leading /): an unanchored pattern
# matches at ANY depth in rsync, which would silently drop generator-owned files
# from the sync (e.g. `ssr/` would swallow a future app/javascript/ssr/ source dir).
EXCLUDES=(
  # git itself doesn't ignore .git
  --exclude='/.git/'

  # Lockfiles — tracked, but environment products: never copied (a lockfile
  # resolved on the generation machine drops the kit's platform entries).
  # The sync workflow refreshes them in the kit context instead.
  --exclude='/Gemfile.lock'
  --exclude='/package-lock.json'

  # Tracked per-repo credentials: the generated file is encrypted with a fresh
  # never-published master.key — copying it would make the kit's undecryptable.
  --exclude='/config/credentials.yml.enc'

  # Deliberate kit keeps: bespoke README, kit-owned deploy pipeline
  # (the generator emits only ci.yml; config/deploy.yml is kamal's, unrelated).
  --exclude='/README.md'
  --exclude='/.github/workflows/deploy.yml'

  # Repo-meta the generator never emits — protect from --delete. None exist in
  # the kits today; insurance so adding one later isn't silently deleted.
  --exclude='/LICENSE'
  --exclude='/LICENSE.md'
  --exclude='/CODE_OF_CONDUCT.md'
  --exclude='/CONTRIBUTING.md'
  --exclude='/.github/FUNDING.yml'
  --exclude='/.github/ISSUE_TEMPLATE/'
  --exclude='/.github/PULL_REQUEST_TEMPLATE.md'

  # Not gitignored by Rails but purely local: bundler's vendored gems.
  --exclude='/vendor/bundle/'
)

# --checksum: rsync's default size+mtime quick-check can skip a changed file
# whose size and timestamp happen to match; content must decide, not clocks.
"$RSYNC" -a --checksum --delete "${EXCLUDES[@]}" --filter=':- .gitignore' "$SRC/" "$DEST/"

echo "Applied generator output: $SRC -> $DEST (kit: $KIT)"
