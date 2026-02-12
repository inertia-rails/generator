#!/bin/bash
set -e

# Compile template once
echo "=== Compiling template ==="
TEMPLATE=$(ruby -e "require 'tmpdir'; puts File.join(Dir.tmpdir, 'inertia_manual_template.rb')")
ruby -e "
  require 'bundler/setup'
  require 'ruby_bytes/cli'
  compiled = RubyBytes::Compiler.new('$(pwd)/template/generator.rb').render
  File.write('$TEMPLATE', compiled)
"
echo "Template: $TEMPLATE"

DEST="${1:-/tmp/inertia_manual}"
rm -rf "$DEST"
mkdir -p "$DEST"
echo "=== Apps will be in: $DEST ==="

generate() {
  local name=$1; shift
  local starter=$1; shift
  local extra_flags=""

  # Starter kit needs mailer + active job for email verification
  if [ "$starter" = "0" ]; then
    extra_flags="--skip-action-mailer --skip-active-job"
  fi

  echo ""
  echo "=== Generating $name ==="
  (
    cd "$DEST"
    env "$@" BUNDLE_IGNORE_MESSAGES=1 \
      rails new "$name" -m "$TEMPLATE" \
        --skip-git --skip-docker --skip-action-mailbox \
        --skip-action-text --skip-active-storage \
        --skip-action-cable --skip-hotwire --skip-jbuilder --skip-test \
        --skip-system-test --skip-kamal --skip-solid --skip-thruster \
        --skip-rubocop --skip-brakeman --skip-ci $extra_flags
  )
  echo "=== Done: $name ==="
}

# ─── Starter Kit configs ─────────────────────────────────────────────
generate react_starter_kit 1 \
  INERTIA_FRAMEWORK=react INERTIA_STARTER_KIT=1 \
  INERTIA_TEST_FRAMEWORK=minitest INERTIA_ALBA=0 INERTIA_TYPELIZER=1

generate vue_starter_kit 1 \
  INERTIA_FRAMEWORK=vue INERTIA_STARTER_KIT=1 \
  INERTIA_TEST_FRAMEWORK=minitest INERTIA_ALBA=0 INERTIA_TYPELIZER=1

generate svelte_starter_kit 1 \
  INERTIA_FRAMEWORK=svelte INERTIA_STARTER_KIT=1 \
  INERTIA_TEST_FRAMEWORK=minitest INERTIA_ALBA=0 INERTIA_TYPELIZER=1

# ─── Foundation configs ──────────────────────────────────────────────
# Full-stack React: TS + Tailwind + shadcn + ESLint + SSR
generate react_full 0 \
  INERTIA_FRAMEWORK=react INERTIA_STARTER_KIT=0 INERTIA_TS=1 INERTIA_TAILWIND=1 \
  INERTIA_SHADCN=1 INERTIA_ESLINT=1 INERTIA_SSR=1 \
  INERTIA_TEST_FRAMEWORK=minitest INERTIA_ALBA=1 INERTIA_TYPELIZER=1

# Vue minimal
generate vue_minimal 0 \
  INERTIA_FRAMEWORK=vue INERTIA_STARTER_KIT=0 INERTIA_TS=0 INERTIA_TAILWIND=0 \
  INERTIA_SHADCN=0 INERTIA_ESLINT=0 INERTIA_SSR=0 \
  INERTIA_TEST_FRAMEWORK=minitest INERTIA_ALBA=0 INERTIA_TYPELIZER=0

# Svelte bare: minimal setup
generate svelte_bare 0 \
  INERTIA_FRAMEWORK=svelte INERTIA_STARTER_KIT=0 INERTIA_TS=0 INERTIA_TAILWIND=0 \
  INERTIA_SHADCN=0 INERTIA_ESLINT=0 INERTIA_SSR=0 \
  INERTIA_TEST_FRAMEWORK=minitest INERTIA_ALBA=0 INERTIA_TYPELIZER=0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All apps generated in: $DEST"
echo ""
echo "To test each app:  cd $DEST/<app> && bin/dev"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
