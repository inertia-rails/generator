# ─── Finalize ────────────────────────────────────────────────────────

say "📦 Finalizing installation...", :cyan

# ─── Install gems ───────────────────────────────────────────────────

# Add remaining gems to Gemfile (rails_vite & inertia_rails already added via add_gem)
gems_to_add.uniq! { |e| e.is_a?(Hash) ? e[:name] : e }
gems_to_add.each do |entry|
  if entry.is_a?(Hash)
    add_gem.(entry[:name], group: entry[:group])
  else
    add_gem.(entry)
  end
end

# Single bundle install for all gems
bundle_run.("bundle install")

if test_framework == "rspec"
  bundle_run.("bundle binstubs rspec-core")
end

# ─── Run migrations (starter kit) ────────────────────────────────────

if use_starter_kit
  bundle_run.("bundle exec rails db:migrate")
end

# ─── Generate Typelizer files ──────────────────────────────────────

if use_typelizer || (use_alba && use_typescript)
  file "config/initializers/typelizer.rb", <%= code("shared/typelizer_initializer.rb.tt") %>
  bundle_run.("bundle exec rails typelizer:generate")
end

# ─── Batch npm install ──────────────────────────────────────────────

npm_packages.uniq!
npm_dev_packages.uniq!

install_cmd  = pm_install[package_manager][:install]
dev_flag     = pm_install[package_manager][:dev_flag]

if npm_packages.any?
  run "#{install_cmd} #{npm_packages.join(' ')}"
end

if npm_dev_packages.any?
  run "#{install_cmd} #{dev_flag} #{npm_dev_packages.join(' ')}"
end

# ─── Run post-install commands (e.g. shadcn CLI) ──────────────────

post_install_commands.each { |cmd| run cmd }

# ─── Re-apply files the shadcn CLI overwrites ────────────────────
# `shadcn add sidebar` pulls its own use-mobile hook as a dependency and
# clobbers ours. The upstream version triggers react-hooks/set-state-in-effect
# (added in eslint-plugin-react-hooks 7.1); ours uses useSyncExternalStore.
if use_starter_kit && framework == "react"
  file "#{js_destination_path}/hooks/use-mobile.ts", <%= code("react/starter/hooks/use-mobile.ts") %>, force: true
end

# ─── Write vite.config ──────────────────────────────────────────────

vite_plugins.uniq! { |p| [p[:import], p[:call]] }

existing_vite_config = Dir.glob(vite_config_glob).first

if existing_vite_config && vite_plugins.any?
  # Existing app: inject plugins into existing config
  vite_config = File.read(existing_vite_config)

  vite_plugins.each do |plugin|
    unless vite_config.include?(plugin[:import])
      prepend_file existing_vite_config, "#{plugin[:import]}\n"
    end
  end

  # Re-read after prepends so call-detection sees current file
  vite_config = File.read(existing_vite_config)

  vite_plugins.each do |plugin|
    unless vite_config.include?(plugin[:call])
      insert_into_file existing_vite_config, "\n    #{plugin[:call]},", after: "plugins: ["
    end
  end

  if !vite_config.include?("noExternal")
    say "  ⚠ For SSR production builds, add this to your vite.config:", :yellow
    say "    ssr: command === 'build' ? { noExternal: true } : {}", :yellow
    say "    (use defineConfig(({ command }) => ({ ... })) form)", :yellow
  end
else
  # Fresh app: write complete vite.config from scratch
  vite_imports = ["import { defineConfig } from 'vite'", "import rails from 'rails-vite-plugin'", "import inertia from '@inertiajs/vite'"]

  # Always configure SSR entrypoint so apps are SSR-ready
  ssr_entrypoint = case framework
    when "react" then "entrypoints/inertia.#{component_ext}"
    else "entrypoints/inertia.#{js_ext}"
  end
  ssr_entry_full = "#{js_destination_path}/#{ssr_entrypoint}"

  vite_calls = ["rails()", "inertia({ ssr: '#{ssr_entry_full}' })"]

  vite_plugins.each do |plugin|
    vite_imports << plugin[:import]
    vite_calls << plugin[:call]
  end

  # SSR config: noExternal for production builds (containerization without node_modules)
  ssr_config = "noExternal: command === 'build' ? true : undefined,"
  if framework == "react"
    # React 19 ships CJS-only — externalize in dev so Node handles require natively
    ssr_config += "\n      external: command === 'serve' ? ['react', 'react-dom', 'react/jsx-runtime', 'react/jsx-dev-runtime'] : undefined,"
  end

  file "vite.config.#{js_ext}", <<~JS
    #{vite_imports.join("\n")}

    export default defineConfig(({ command }) => ({
      ssr: {
        #{ssr_config}
      },
      plugins: [
        #{vite_calls.join(",\n    ")},
      ],
    }))
  JS
end

# ─── Auto-fix lint issues ────────────────────────────────────────────

if use_eslint
  unless run("#{package_manager} run lint:fix", abort_on_failure: false)
    say "  ⚠ lint:fix exited with errors (non-critical, continuing)", :yellow
  end
  run("#{package_manager} run format:fix", abort_on_failure: false)
end

# ─── Create/update Procfile.dev ──────────────────────────────────────

vite_dev_cmd = case package_manager
  when "yarn" then "yarn vite"
  when "pnpm" then "pnpm vite"
  when "bun" then "bun run vite"
  else "npx vite"
end

file "Procfile.dev", "web: bin/rails s -p ${PORT:-3000}\njs: #{vite_dev_cmd}\n", force: fresh_app

# ─── Create bin/dev ──────────────────────────────────────────────────

file "bin/dev", <%= code("shared/dev.tt") %>, force: fresh_app
chmod "bin/dev", 0o755

# ─── Post-install verification ─────────────────────────────────────

say "🔍 Verifying installation...", :cyan

if in_root { run("bundle exec rails runner 'puts :ok'") }
  say "  Rails boot check passed ✓", :green
else
  say "  ⚠ Rails boot check failed (the app may still work — check the error above)", :yellow
end

# ─── Summary (after all post-template steps) ─────────────────────────

after_bundle do
  say ""
  say "━━━ Inertia Rails installed successfully! ━━━━━━━━━━━━━━━━━━━━━", :green
  say ""
  say "  Start the development server:", :cyan
  say "    bin/dev"
  say ""

  if use_starter_kit
    say "  Starter Kit with authentication is ready.", :cyan
    say ""
  end

  if use_ssr
    say "  SSR is enabled. Production build:", :cyan
    say "    #{vite_dev_cmd.split.first} vite build --ssr"
    say ""
  else
    say "  SSR-ready. To enable, add to config/initializers/inertia_rails.rb:", :cyan
    say "    config.ssr_enabled = true"
    say ""
  end

  if importmap_detected
    say "  ⚠ importmap-rails is still installed.", :yellow
    say "    It works alongside Vite but you may want to remove it.", :yellow
    say ""
  end

  say "  Learn more: https://inertia-rails.dev", :cyan
  say ""
end
