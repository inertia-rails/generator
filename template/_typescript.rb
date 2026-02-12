# ─── TypeScript Configuration ────────────────────────────────────────

if use_typescript
  say "📦 Setting up TypeScript...", :cyan

  case framework
  when "react"
    npm_dev_packages.push("@types/react", "@types/react-dom", "typescript@~5.8")
    file "tsconfig.json", <%= code("shared/tsconfig.json.tt") %>
    file "tsconfig.app.json", <%= code("react/tsconfig.app.json.tt") %>
    file "tsconfig.node.json", <%= code("react/tsconfig.node.json.tt") %>
    check_script = "tsc -p tsconfig.app.json && tsc -p tsconfig.node.json"
  when "vue"
    npm_dev_packages.push("typescript@~5.8", "vue-tsc")
    file "tsconfig.json", <%= code("shared/tsconfig.json.tt") %>
    file "tsconfig.app.json", <%= code("vue/tsconfig.app.json.tt") %>
    file "tsconfig.node.json", <%= code("vue/tsconfig.node.json.tt") %>
    check_script = "vue-tsc -p tsconfig.app.json && tsc -p tsconfig.node.json"
  when "svelte"
    npm_dev_packages.push("@tsconfig/svelte@5", "svelte-check", "typescript@~5.8", "tslib")
    file "tsconfig.json", <%= code("svelte/tsconfig.json.tt") %>
    file "tsconfig.node.json", <%= code("svelte/tsconfig.node.json.tt") %>
    check_script = "svelte-check --tsconfig ./tsconfig.json && tsc -p tsconfig.node.json"
  end

  # Copy type definition files
  case framework
  when "react"
    file "#{js_destination_path}/types/vite-env.d.ts", <%= code("react/vite-env.d.ts") %>
  when "svelte"
    file "#{js_destination_path}/types/vite-env.d.ts", <%= code("svelte/vite-env.d.ts") %>
  else
    file "#{js_destination_path}/types/vite-env.d.ts", <%= code("shared/vite-env.d.ts") %>
  end
  file "#{js_destination_path}/types/globals.d.ts", <%= code("shared/globals.d.ts") %>
  file "#{js_destination_path}/types/index.ts", <%= code("shared/types-index.ts") %>

  # Add check script to package.json
  update_package_json.call do |pkg|
    pkg["scripts"] ||= {}
    pkg["scripts"]["check"] = check_script
  end

  say "  TypeScript configured ✓", :green
end
