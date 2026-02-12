# ─── Typelizer (route helpers) ────────────────────────────────────────

if use_typelizer
  say "📦 Setting up route helpers (Typelizer)...", :cyan

  add_gem.("typelizer")

  # Gitignore generated routes (regenerated on boot/deploy)
  if File.exist?(".gitignore")
    append_to_file ".gitignore", "\n# Generated Typelizer route helpers\n/#{js_destination_path}/routes/*\n"
  end

  # Exclude generated routes files from ESLint
  eslint_ignores << "routes/**"

  say "  Route helpers configured ✓", :green
end
