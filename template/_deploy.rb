# ─── Deployment Infrastructure ────────────────────────────────────────
# Dockerfile, CI workflow, Dependabot
#
# `*_version` vars are `||=` so test fixtures can preset them.

detect_version = ->(cmd, default) do
  `#{cmd} --version`[/\d+\.\d+\.\d+/] || default
rescue SystemCallError
  default
end

# yarn 2+ uses corepack, yarn 1.x uses `npm install -g`. "latest" → corepack (Rails' default).
yarn_version ||= ENV.fetch("YARN_VERSION") { detect_version.("yarn", "latest") } if package_manager == "yarn"
yarn_through_corepack = package_manager == "yarn" &&
  (yarn_version == "latest" || Gem::Version.new(yarn_version) >= Gem::Version.new("2"))

js_ci_install_cmd =
  if package_manager == "yarn"
    yarn_through_corepack ? "yarn install --immutable" : "yarn install --frozen-lockfile"
  else
    pm_install[package_manager][:ci]
  end

# ─── Generate Dockerfile ─────────────────────────────────────────────

if File.exist?("Dockerfile")
  app_name = File.basename(destination_root)
  ruby_version = File.exist?(".ruby-version") ? File.read(".ruby-version").strip.delete_prefix("ruby-") : Gem.ruby_version.to_s
  node_version ||= ENV.fetch("NODE_VERSION") { detect_version.("node", "22.22.2") } if package_manager != "bun"
  bun_version  ||= ENV.fetch("BUN_VERSION")  { detect_version.("bun",  "1.3.0") }   if package_manager == "bun"
  pnpm_version ||= ENV.fetch("PNPM_VERSION") { detect_version.("pnpm", "10") }      if package_manager == "pnpm"

  # Trilogy is a pure-Ruby MySQL client — no build deps. Base still keeps the
  # CLI for dbconsole/mysqldump (matches Rails 8's database.rb).
  db_base_pkg = case db_adapter
    when "postgresql"        then "postgresql-client"
    when "mysql2", "trilogy" then "default-mysql-client"
    else "sqlite3"
  end

  db_build_pkg = case db_adapter
    when "postgresql" then "libpq-dev"
    when "mysql2"     then "default-libmysqlclient-dev"
    else nil
  end

  # libvips is loaded by ruby-vips at runtime via FFI, so only the base stage needs it.
  needs_libvips = gem_in_gemfile.("image_processing") || File.exist?("config/storage.yml")

  dockerfile_base_packages = ["curl", db_base_pkg, ("libvips" if needs_libvips), "libjemalloc2"].compact.sort

  dockerfile_build_packages = [
    "build-essential", "git", "pkg-config", "libyaml-dev",
    db_build_pkg,
    *(package_manager == "bun" ? ["unzip"] : %w(node-gyp python-is-python3))
  ].compact.sort

  depend_on_bootsnap = gem_in_gemfile.("bootsnap")
  use_thruster = gem_in_gemfile.("thruster")

  file "Dockerfile", <%= code("shared/Dockerfile.tt") %>, force: fresh_app
  say "  Dockerfile: generated (SSR=#{use_ssr}, toggle via --build-arg SSR_ENABLED) ✓", :green
end

# ─── Generate CI workflow ────────────────────────────────────────────

ci_workflow = ".github/workflows/ci.yml"
if File.exist?(ci_workflow)
  if fresh_app
    file ci_workflow, <%= code("shared/ci.yml.tt") %>, force: true
    say "  CI: generated workflow with lint_js + Node.js ✓", :green
  else
    # ── Existing app: minimal fixes ────────────────────────────────────

    ci_content = File.read(ci_workflow)

    # Remove broken scan_js job (importmap no longer exists)
    if ci_content.include?("bin/importmap audit")
      lines = ci_content.lines
      result = []
      skip = false
      lines.each do |line|
        if line.match?(/^  scan_js:/)
          skip = true
          next
        end
        if skip && line.match?(/^  \w/)
          skip = false
        end
        result << line unless skip
      end
      File.write(File.join(destination_root, ci_workflow), result.join)
      say "  CI: removed broken scan_js job ✓", :green
    end

    # Create separate lint_js workflow
    file ".github/workflows/lint_js.yml", <%= code("shared/lint_js.yml.tt") %>
    say "  CI: created lint_js workflow ✓", :green
    say "  ⚠ You may want to add Node.js setup to the test job in #{ci_workflow}", :yellow
  end
end

# ─── bin/ci runner (config/ci.rb) ─────────────────────────────────────
# Rails' default runs importmap:audit (removed with Inertia+Vite) and bin/rails
# test (wrong for rspec). Replace it with a Vite/Inertia-aware version.
ci_runner = "config/ci.rb"
if fresh_app && File.exist?(ci_runner)
  file ci_runner, <%= code("shared/ci.rb.tt") %>, force: true
  say "  CI: generated bin/ci runner ✓", :green
end

# ─── Add npm to Dependabot ────────────────────────────────────────────

dependabot_file = ".github/dependabot.yml"
if File.exist?(dependabot_file)
  dependabot_config = File.read(dependabot_file)
  unless dependabot_config.include?("package-ecosystem: npm")
    append_with_blank_line.(dependabot_file, <<~YAML)
      - package-ecosystem: npm
        directory: "/"
        schedule:
          interval: weekly
    YAML
    say "  Dependabot: added npm ecosystem ✓", :green
  end
end

# ─── Kamal deploy config (Vite-aware) ─────────────────────────────────
# `rails new` generates the kamal files AFTER applying this template
# (run_kamal follows apply_rails_template), so edit them in after_bundle.
if fresh_app
  after_bundle do
    deploy_yml = "config/deploy.yml"
    if File.exist?(deploy_yml)
      # Vite outputs to public/vite — bridge the whole public dir, not just public/assets
      gsub_file deploy_yml, "asset_path: /rails/public/assets", "asset_path: /rails/public"

      # Registry-backed build cache
      builder_anchor = "builder:\n  arch: amd64\n"
      if File.read(deploy_yml).include?(builder_anchor) && !File.read(deploy_yml).include?("cache:")
        insert_into_file deploy_yml,
          "  cache:\n    type: registry\n    image: your-user/#{File.basename(destination_root)}-build-cache\n    options: mode=max\n",
          after: builder_anchor
      end
    end
  end
end
