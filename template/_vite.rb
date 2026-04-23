# ─── Rails Vite Installation ─────────────────────────────────────────

# Ensure package.json exists with app name and ESM type
unless File.exist?("package.json")
  say "  Creating package.json", :yellow
  File.write("package.json", <<~JSON)
    {
      "name": "#{app_name}",
      "private": true,
      "type": "module"
    }
  JSON
end

# Pin Vite 8 via overrides (some deps like @inertiajs/vite haven't updated peer deps yet)
update_package_json.call do |pkg|
  case package_manager
  when "pnpm"
    pkg["pnpm"] ||= {}
    (pkg["pnpm"]["overrides"] ||= {})["vite"] = "$vite"
  when "yarn"
    (pkg["resolutions"] ||= {})["vite"] = "$vite"
  else
    (pkg["overrides"] ||= {})["vite"] = "$vite"
  end
end

unless vite_installed
  say "📦 Setting up Rails Vite...", :cyan

  add_gem.("rails_vite", comment: "Vite integration [https://github.com/skryukov/rails_vite]")

  # Create entrypoints directory
  empty_directory "#{js_destination_path}/entrypoints"

  # Add npm dev dependencies
  npm_dev_packages.push("rails-vite-plugin", "vite@^8")

  # Add .gitignore entries
  if File.exist?(".gitignore")
    append_with_blank_line.(".gitignore", <<~GITIGNORE)
      # Vite
      /public/vite*
      node_modules
      *.local
    GITIGNORE
  end

  # Add package manager install to bin/setup
  if File.exist?("bin/setup")
    unless File.read("bin/setup").include?("#{package_manager} install")
      insert_into_file "bin/setup", "\n  system! \"#{package_manager} install\"",
        after: 'system("bundle check") || system!("bundle install")'
    end
  end

  vite_installed = true
  say "  Rails Vite configured ✓", :green
else
  say "  Rails Vite already installed, skipping", :green
end
