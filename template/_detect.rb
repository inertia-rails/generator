# ─── Detection ────────────────────────────────────────────────────────

say "🔍 Detecting existing setup...", :cyan

# Detect fresh app vs existing app (rails new -m ... vs rails app:template)
# Allow pre-set value (e.g. from tests) to take precedence
fresh_app = !ARGV.any? { |a| a.include?("app:template") } if fresh_app.nil?

say fresh_app ? "  Detected: fresh Rails app" : "  Detected: existing Rails app"

# Detect API-only mode
if options[:api]
  say "❌ Inertia requires a full Rails app (not API-only).", :red
  say "   Please re-run without --api or set config.api_only = false.", :red
  exit(1)
end

# Detect package manager from lock files
package_manager = if File.exist?("package-lock.json")
  "npm"
elsif File.exist?("bun.lockb") || File.exist?("bun.lock")
  "bun"
elsif File.exist?("pnpm-lock.yaml")
  "pnpm"
elsif File.exist?("yarn.lock")
  "yarn"
else
  "npm"
end

say "  Package manager: #{package_manager}"

# Blocker: jsbundling/cssbundling break assets:precompile when Vite replaces their build scripts
if gem_in_gemfile.("jsbundling-rails") || gem_in_gemfile.("cssbundling-rails")
  say ""
  say "❌ jsbundling-rails and/or cssbundling-rails detected.", :red
  say "   This generator sets up Vite, which conflicts with these gems.", :red
  say ""
  say "   Options:", :yellow
  say "     1. Migrate to Vite: https://vite-ruby.netlify.app/guide/migration", :yellow
  say "     2. Remove the conflicting gems and re-run this generator", :yellow
  say "     3. Set up Inertia manually: https://inertia-rails.dev/guide/server-side-setup", :yellow
  say ""
  exit(1)
end

# Existing app: detect what's already installed
unless fresh_app
  # Track importmap for post-install warning
  importmap_detected = gem_in_gemfile.("importmap-rails")

  # Detect Vite
  vite_installed = Dir.glob(vite_config_glob).any? && gem_in_gemfile.("rails_vite")
  say "  Rails Vite: #{vite_installed ? 'installed' : 'not installed'}"

  # Detect framework from package.json
  pkg = JSON.parse(File.read("package.json")) rescue {}
  deps = (pkg["dependencies"] || {}).merge(pkg["devDependencies"] || {})

  if deps.key?("@inertiajs/react") || deps.key?("react")
    framework_detected = "react"
  elsif deps.key?("@inertiajs/vue3") || deps.key?("vue")
    framework_detected = "vue"
  elsif deps.key?("@inertiajs/svelte") || deps.key?("svelte")
    framework_detected = "svelte"
  end

  say "  Framework: #{framework_detected || 'none detected'}"

  # Detect TypeScript
  typescript_detected = File.exist?("tsconfig.json")
  say "  TypeScript: #{typescript_detected ? 'detected' : 'not detected'}"

  # Detect Tailwind
  tailwind_detected = deps.key?("tailwindcss")
  say "  Tailwind CSS: #{tailwind_detected ? 'detected' : 'not detected'}"

  # Detect frontend source directory (vite-ruby/rails_vite convention is `entrypoints/`)
  js_destination_detected = %w[app/frontend app/javascript app/client].find { |p|
    Dir.exist?("#{p}/entrypoints")
  }
  say "  Frontend dir: #{js_destination_detected || 'app/javascript (default)'}"
end

# Detect database adapter (for Dockerfile / CI)
db_adapter = if gem_in_gemfile.("pg")
  "postgresql"
elsif gem_in_gemfile.("mysql2")
  "mysql2"
elsif gem_in_gemfile.("trilogy")
  "trilogy"
else
  "sqlite3"
end

say "  Detection complete ✓", :green
