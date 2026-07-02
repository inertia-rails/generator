# ─── Typelizer (route helpers) ────────────────────────────────────────

if use_typelizer
  say "📦 Setting up route helpers (Typelizer)...", :cyan

  inertia_gem_anchor = "gem \"inertia_rails\", \"~> 3.21\"\n"
  if !gem_in_gemfile.("typelizer") && File.exist?("Gemfile") && File.read("Gemfile").include?(inertia_gem_anchor)
    insert_into_file "Gemfile",
      "\n# Brings Rails named routes to javascript\ngem \"typelizer\"\n",
      after: inertia_gem_anchor
  else
    add_gem.("typelizer")
  end

  # Generated routes are committed so frontend-only workflows (npm ci && npm run
  # lint/check/build) work without Ruby. Typelizer still regenerates on boot.
  # Exclude from ESLint since it's generated code.
  eslint_ignores << "routes/**"

  say "  Route helpers configured ✓", :green
end
