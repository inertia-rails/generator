#!/usr/bin/env bash
#
# Apply freshly-generated starter-kit output over a checked-out kit repo.
#
# Model: "generator wins by overwrite; the keep-list is the sanctioned exception."
# The whole tree is synced with --delete, so files the generator no longer emits
# are removed and the kit stays a faithful output — EXCEPT the keep-list below
# (per-app secrets, regenerated lockfiles, build artifacts, stable schema, and the
# deliberate kit-specific keeps), which are never overwritten or deleted.
#
# Usage: bin/sync_apply.sh <generated-app-dir> <kit-clone-dir> <kit-name>
set -euo pipefail

SRC="${1:?usage: sync_apply.sh <generated-app-dir> <kit-clone-dir> <kit-name>}"
DEST="${2:?usage: sync_apply.sh <generated-app-dir> <kit-clone-dir> <kit-name>}"
KIT="${3:?usage: sync_apply.sh <generated-app-dir> <kit-clone-dir> <kit-name>}"

EXCLUDES=(
  # VCS / dependencies / build artifacts / logs — not generator-owned
  --exclude='.git/'
  --exclude='node_modules/'
  --exclude='tmp/'
  --exclude='log/'
  --exclude='storage/'
  --exclude='public/'
  --exclude='vendor/'
  --exclude='ssr/'
  --exclude='.bundle/'

  # Lockfiles — regenerated in the kit context (never copied: the frozen-mismatch rule)
  --exclude='Gemfile.lock'
  --exclude='package-lock.json'

  # Per-app secrets — unique per repo, never sync
  --exclude='config/master.key'
  --exclude='config/credentials.yml.enc'

  # Stable schema. The generator re-timestamps migrations on every run, so syncing
  # db/ would duplicate the users/sessions migrations. Genuinely-new migrations are
  # surfaced in the PR body (see the workflow) rather than applied automatically.
  --exclude='db/'

  # Deliberate kit keeps
  --exclude='README.md'
  --exclude='.github/workflows/deploy.yml'

  # Repo-meta the generator never emits — protect from --delete
  --exclude='LICENSE'
  --exclude='LICENSE.md'
  --exclude='CODE_OF_CONDUCT.md'
  --exclude='CONTRIBUTING.md'
  --exclude='.github/FUNDING.yml'
  --exclude='.github/ISSUE_TEMPLATE/'
  --exclude='.github/PULL_REQUEST_TEMPLATE.md'
  --exclude='.env'
  --exclude='.env.*'
)

# react-starter-kit keeps its own Inertia entrypoint (the .catch root-element guard).
if [ "$KIT" = "react" ]; then
  EXCLUDES+=(--exclude='app/javascript/entrypoints/inertia.tsx')
fi

rsync -a --delete "${EXCLUDES[@]}" "$SRC/" "$DEST/"

echo "Applied generator output: $SRC -> $DEST (kit: $KIT)"
