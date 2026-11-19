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

# vite_rails docs and habits rely on bin/vite (`bin/vite dev`, `bin/vite build`)
if vite_gem == "vite_rails" && !File.exist?("bin/vite")
  bundle_run.("bundle binstubs vite_ruby")
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

# shadcn-vue's DropdownMenuSubTrigger ships [class*=\'text-\'] escaped
# inside a single-quoted :class string; prettier later drops the escapes,
# leaving nested quotes that break the Vue compiler. Drop the inner quotes
# entirely — attribute selectors accept unquoted idents.
if framework == "vue" && use_shadcn
  sub_trigger = "#{js_destination_path}/components/ui/dropdown-menu/DropdownMenuSubTrigger.vue"
  if File.exist?(sub_trigger)
    gsub_file sub_trigger, /\[class\*=\\?'(text-|size-)\\?'\]/, '[class*=\1]'
  end
end

# ─── Write vite.config ──────────────────────────────────────────────

vite_plugins.uniq! { |p| [p[:import], p[:call]] }

existing_vite_config = Dir.glob(vite_config_glob).first

# Always configure SSR entrypoint so apps are SSR-ready
ssr_entrypoint = case framework
  when "react" then "entrypoints/inertia.#{component_ext}"
  else "entrypoints/inertia.#{js_ext}"
end
ssr_entry_full = "#{js_destination_path}/#{ssr_entrypoint}"
# vite_rails makes the source folder the Vite root, so paths start from there
ssr_entry_for_vite = (vite_gem == "vite_rails") ? ssr_entrypoint : ssr_entry_full

# Framework plugins first, then tailwind
tailwind_plugins, framework_plugins = vite_plugins.partition { |p| p[:import].include?("tailwindcss") }
vite_plugins = framework_plugins + tailwind_plugins

if existing_vite_config
  # Existing app: add what is missing to the existing config. Plugins go at
  # the end of the array, in order: inertia() placed before the Rails plugin
  # makes SSR builds emit a duplicate bundle.
  vite_config = File.read(existing_vite_config)

  # A plugin is present when its function is called at all, so an existing
  # `react({ ... })` is not doubled by a bare `react()`
  missing_plugins = vite_plugins.reject { |plugin| vite_config.match?(/\b#{plugin[:call][/\A\w+/]}\(/) }
  unless vite_config.include?("@inertiajs/vite")
    missing_plugins << { import: "import inertia from '@inertiajs/vite'", call: "inertia({ ssr: '#{ssr_entry_for_vite}' })" }
  end

  missing_imports = missing_plugins.map { |plugin| plugin[:import] }.reject { |import| vite_config.include?(import) }
  # babel()'s preset is exported by the React plugin, whose import we leave
  # alone when react() is already set up
  if missing_plugins.any? { |plugin| plugin[:call].include?("reactCompilerPreset") } &&
      !"#{vite_config}#{missing_imports.join}".include?("reactCompilerPreset")
    missing_imports << "import { reactCompilerPreset } from '@vitejs/plugin-react'"
  end
  prepend_file existing_vite_config, "#{missing_imports.join("\n")}\n" if missing_imports.any?

  if missing_plugins.any?
    vite_config = File.read(existing_vite_config)
    # The array closes at the indentation of the line that opens it; deeper
    # brackets belong to plugin options
    updated = vite_config.sub(/^([ \t]*+)([^\n]*plugins:\s*\[.*?),?(\n\1\])/m) do
      indent, head, tail = $1, $2, $3
      calls = missing_plugins.map { |plugin| "\n#{indent}  #{plugin[:call]}," }.join
      "#{indent}#{head}#{"," unless head.end_with?("[")}#{calls}#{tail}"
    end

    if updated == vite_config
      say "  ⚠ Could not find a multi-line `plugins: [` array in #{existing_vite_config}.", :yellow
      missing_plugins.each { |plugin| say "    Add this plugin manually: #{plugin[:call]}", :yellow }
    else
      File.write(File.join(destination_root, existing_vite_config), updated)
    end
  end

  if !vite_config.include?("noExternal")
    say "  ⚠ For SSR production builds, add this to your vite.config:", :yellow
    say "    ssr: command === 'build' ? { noExternal: true } : {}", :yellow
    say "    (use defineConfig(({ command }) => ({ ... })) form)", :yellow
  end
else
  # Fresh app: write complete vite.config from scratch
  rails_plugin_import, rails_plugin_call =
    if vite_gem == "vite_rails"
      ["import ViteRuby from 'vite-plugin-ruby'", "ViteRuby()"]
    else
      ["import rails from 'rails-vite-plugin'", "rails()"]
    end
  vite_imports = ["import { defineConfig } from 'vite'", rails_plugin_import, "import inertia from '@inertiajs/vite'"]

  # rails + inertia go last
  vite_calls = []
  vite_plugins.each do |plugin|
    vite_imports << plugin[:import]
    vite_calls << plugin[:call]
  end
  vite_calls << rails_plugin_call
  vite_calls << "inertia({ ssr: '#{ssr_entry_for_vite}' })"

  # SSR config: noExternal for production builds (containerization without node_modules)
  ssr_config = "// Prebuild ssr.js so we can drop node_modules from the container.\n      noExternal: command === 'build' ? true : undefined,"
  if framework == "react"
    ssr_config += "\n      // React 19 ships CJS-only — externalize in dev so Node handles require natively.\n      external: command === 'serve' ? ['react', 'react-dom', 'react/jsx-runtime', 'react/jsx-dev-runtime'] : undefined,"
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

vite_runner = pm_install[package_manager][:run]

file "Procfile.dev", "web: bin/rails s -p ${PORT:-3000}\njs: #{vite_runner} vite\n", force: fresh_app

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
    say "    #{vite_runner} vite build --ssr"
    say ""
  else
    say "  SSR-ready. Flip config.ssr_enabled in config/initializers/inertia_rails.rb to enable.", :cyan
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
