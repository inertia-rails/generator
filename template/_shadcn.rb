# ─── shadcn/ui ───────────────────────────────────────────────────────

if use_shadcn
  say "📦 Setting up shadcn/ui...", :cyan

  eslint_ignores << "components/ui/**"

  # Match what `shadcn init` / `shadcn-vue init` / `shadcn-svelte init` install
  npm_dev_packages.push("clsx", "tailwind-merge", "tw-animate-css")

  if use_typescript
    utils_content = <%= code("shared/utils.ts") %>
  else
    utils_content = <%= code("shared/utils.js") %>
  end

  case framework
  when "react"
    file "#{js_destination_path}/lib/utils.#{js_ext}", utils_content
    file "components.json", <%= code("react/components.json.tt") %>
    npm_dev_packages.push("class-variance-authority", "lucide-react", "radix-ui")
  when "vue"
    file "#{js_destination_path}/lib/utils.#{js_ext}", utils_content
    file "components.json", <%= code("vue/components.json.tt") %>
    npm_dev_packages.push("class-variance-authority", "lucide-vue-next")
  when "svelte"
    # Svelte shadcn uses @/utils (not @/lib/utils) — the CLI generates additional
    # types (WithElementRef, WithoutChildren) in utils.ts that components depend on
    file "#{js_destination_path}/utils.#{js_ext}", utils_content
    file "components.json", <%= code("svelte/components.json.tt") %>
    npm_dev_packages.push("@lucide/svelte", "tailwind-variants")
  end

  # JS projects need jsconfig.json for @ path alias (TS projects get this from tsconfig.json)
  unless use_typescript
    file "jsconfig.json", <%= code("shared/jsconfig.json.tt") %>
  end

  # Build shadcn CLI command for post-install (needs npm packages installed first)
  if use_starter_kit
    shadcn_cli = case framework
      when "vue" then "shadcn-vue@latest"
      when "svelte" then "shadcn-svelte@latest"
      else "shadcn@latest"
    end

    shadcn_components = %w[
      alert avatar badge breadcrumb button card checkbox collapsible
      dialog dropdown-menu input label navigation-menu separator
      sheet sidebar skeleton sonner toggle toggle-group tooltip
    ]

    case framework
    when "react"
      # spinner and select are only available in the React shadcn registry
      shadcn_components.push("spinner", "select")
    end

    pm_exec = pm_install[package_manager][:exec]
    post_install_commands << "#{pm_exec} #{shadcn_cli} add #{shadcn_components.join(' ')} --yes --overwrite"
  end

  say "  shadcn/ui configured ✓", :green
end
