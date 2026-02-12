# ─── Deployment Infrastructure ────────────────────────────────────────
# Dockerfile, CI workflow, Dependabot

js_ci_install_cmd = case package_manager
  when "yarn" then "yarn install --immutable"
  when "pnpm" then "pnpm install --frozen-lockfile"
  when "bun"  then "bun install --frozen-lockfile"
  else "npm ci"
end

# ─── Generate Dockerfile ─────────────────────────────────────────────

if File.exist?("Dockerfile")
  ruby_version = File.exist?(".ruby-version") ? File.read(".ruby-version").strip : RUBY_VERSION

  db_base_pkg = case db_adapter
    when "postgresql" then "postgresql-client"
    when "mysql2", "trilogy" then "default-mysql-client"
    else "sqlite3"
  end

  db_build_pkg = case db_adapter
    when "postgresql" then "libpq-dev"
    when "mysql2" then "default-libmysqlclient-dev"
    else nil
  end

  use_thruster = gem_in_gemfile.("thruster")

  file "Dockerfile", <%= code("shared/Dockerfile.tt") %>, force: fresh_app
  say "  Dockerfile: generated with Node.js support ✓", :green
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

# ─── Add npm to Dependabot ────────────────────────────────────────────

dependabot_file = ".github/dependabot.yml"
if File.exist?(dependabot_file)
  dependabot_config = File.read(dependabot_file)
  unless dependabot_config.include?("package-ecosystem: npm")
    append_to_file dependabot_file, <<~YAML

      - package-ecosystem: npm
        directory: "/"
        schedule:
          interval: weekly
    YAML
    say "  Dependabot: added npm ecosystem ✓", :green
  end
end
