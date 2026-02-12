# ─── ESLint + Prettier ───────────────────────────────────────────────

if use_eslint
  say "📦 Setting up ESLint + Prettier...", :cyan

  # Common dev packages (all frameworks)
  npm_dev_packages.push("prettier", "eslint@9", "eslint-plugin-import")

  if use_typescript
    npm_dev_packages << "eslint-import-resolver-typescript"
  end

  # Framework-specific packages + config
  case framework
  when "react"
    npm_dev_packages.push("@eslint/js@9", "eslint-config-prettier", "globals", "eslint-plugin-react", "eslint-plugin-react-hooks")
    npm_dev_packages << "typescript-eslint" if use_typescript
    file "eslint.config.js", <%= code("react/eslint.config.js") %>
  when "svelte"
    npm_dev_packages.push("@eslint/js@9", "eslint-config-prettier", "globals", "eslint-plugin-svelte")
    npm_dev_packages << "typescript-eslint" if use_typescript
    file "eslint.config.js", <%= code("svelte/eslint.config.js") %>
  when "vue"
    npm_dev_packages.push("@vue/eslint-config-prettier", "eslint-plugin-vue")
    npm_dev_packages << "@vue/eslint-config-typescript" if use_typescript
    file "eslint.config.js", <%= code("vue/eslint.config.js") %>
  end

  # Prettier config
  if use_tailwind
    npm_dev_packages << "prettier-plugin-tailwindcss"
    file ".prettierrc", <%= code("shared/prettierrc-tailwind.json") %>
  else
    file ".prettierrc", <%= code("shared/prettierrc.json") %>
  end

  # .prettierignore
  file ".prettierignore", <<~TXT
    build
    coverage
    #{js_destination_path}/routes
  TXT

  # Add lint scripts to package.json
  root_files = "'*.{js,mjs,cjs,ts}'"
  update_package_json.call { |pkg|
    pkg["scripts"] ||= {}
    pkg["scripts"]["lint"] = "eslint #{root_files} #{js_destination_path}/ --report-unused-disable-directives --max-warnings 0"
    pkg["scripts"]["lint:fix"] = "eslint #{root_files} #{js_destination_path}/ --fix"
    pkg["scripts"]["format"] = "prettier --check '#{js_destination_path}' #{root_files}"
    pkg["scripts"]["format:fix"] = "prettier --write '#{js_destination_path}' #{root_files}"
  }

  say "  ESLint + Prettier configured ✓", :green
end
