# ─── Starter Kit Frontend ──────────────────────────────────────────────

if use_starter_kit
  say "📦 Setting up Starter Kit frontend...", :cyan

  # ─── Additional npm packages ──────────────────────────────────────
  case framework
  when "react"
    npm_packages << "@headlessui/react"
  when "vue"
    npm_packages << "@vueuse/core"
  when "svelte"
    npm_packages << "mode-watcher"
  end

  # ─── CSS entrypoint (override with themed version) ───────────────
  file "#{js_destination_path}/entrypoints/application.css", <%= code("shared/starter-application.css") %>, force: true

  # ─── Shared lib files (SSR helpers, storage) ────────────────────
  file "#{js_destination_path}/lib/browser.ts", <%= code("shared/starter_lib/browser.ts") %>, force: true
  file "#{js_destination_path}/lib/storage.ts", <%= code("shared/starter_lib/storage.ts") %>, force: true

  # ─── Framework-specific files (auto-generated from directory tree) ─
  case framework
  when "react"
<%= copy_dir("react/starter", "js_destination_path", force: true) %>
  when "vue"
<%= copy_dir("vue/starter", "js_destination_path", force: true) %>
  when "svelte"
<%= copy_dir("svelte/starter", "js_destination_path", force: true) %>
  end

  say "  Starter Kit frontend configured ✓", :green
end
