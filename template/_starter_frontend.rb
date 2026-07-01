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

  # ─── Dark-mode guard: set the theme class inline before assets load (avoids FOUC) ─
  layout_file = "app/views/layouts/application.html.erb"
  icon_anchor = "<link rel=\"apple-touch-icon\" href=\"/icon.png\">"
  if File.exist?(layout_file) && File.read(layout_file).include?(icon_anchor) &&
      !File.read(layout_file).include?("Inline to avoid FOUC")
    insert_into_file layout_file,
      "\n\n    <script>\n" \
      "      <%%# Enable dark mode based on localStorage or system preference. Inline to avoid FOUC. %>\n" \
      "      document.documentElement.classList.toggle(\n" \
      "        \"dark\",\n" \
      "        localStorage.appearance === \"dark\" ||\n" \
      "          (!(\"appearance\" in localStorage) && window.matchMedia(\"(prefers-color-scheme: dark)\").matches),\n" \
      "      );\n" \
      "    </script>",
      after: icon_anchor
  end

  say "  Starter Kit frontend configured ✓", :green
end
