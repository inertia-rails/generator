# ─── Typelizer (route helpers) ────────────────────────────────────────

if use_typelizer
  say "📦 Setting up route helpers (Typelizer)...", :cyan

  add_gem.("typelizer")

  # Generated routes are committed so frontend-only workflows (npm ci && npm run
  # lint/check/build) work without Ruby. Typelizer still regenerates on boot.
  # Exclude from ESLint since it's generated code.
  eslint_ignores << "routes/**"

  say "  Route helpers configured ✓", :green
end
