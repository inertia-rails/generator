# ─── Tailwind CSS v4 ─────────────────────────────────────────────────

if use_tailwind
  unless tailwind_detected
    say "📦 Setting up Tailwind CSS v4...", :cyan

    npm_dev_packages.push("tailwindcss", "@tailwindcss/vite", "@tailwindcss/forms", "@tailwindcss/typography")

    vite_plugins << { import: "import tailwindcss from '@tailwindcss/vite'", call: "tailwindcss()" }

    # Create CSS entrypoint
    file "#{js_destination_path}/entrypoints/application.css", <%= code("shared/application.css") %>

    say "  Tailwind CSS v4 configured ✓", :green
  else
    say "  Tailwind CSS already installed, skipping", :green
  end
end
