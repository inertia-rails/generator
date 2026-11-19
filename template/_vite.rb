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

unless vite_installed
  say "📦 Setting up #{(vite_gem == "vite_rails") ? "Vite Rails" : "Rails Vite"}...", :cyan

  # Slot the Vite gem after the asset-related gems; fall back to appending
  # when the anchor is missing (existing/customized Gemfiles).
  vite_gem_comment = (vite_gem == "vite_rails") ?
    "Vite integration [https://vite-ruby.netlify.app]" :
    "Vite integration [https://github.com/skryukov/rails_vite]"
  image_processing_anchor = "gem \"image_processing\", \"~> 1.2\"\n"
  if !gem_in_gemfile.(vite_gem) && File.exist?("Gemfile") && File.read("Gemfile").include?(image_processing_anchor)
    insert_into_file "Gemfile",
      "\ngem \"#{vite_gem}\" # #{vite_gem_comment}\n",
      after: image_processing_anchor
  else
    add_gem.(vite_gem, comment: vite_gem_comment)
  end

  # Create entrypoints directory
  empty_directory "#{js_destination_path}/entrypoints"

  # Add npm dev dependencies
  npm_dev_packages.push((vite_gem == "vite_rails") ? "vite-plugin-ruby" : "rails-vite-plugin", "vite@^8")

  # vite_rails reads its settings from config/vite.json. Same source folder as
  # rails_vite, and no Rack proxy in development: the browser talks to the
  # Vite dev server, as in the config `vite install` writes.
  # The SSR build reuses the Inertia entrypoint instead of a separate ssr/ssr.js.
  if vite_gem == "vite_rails"
    file "config/vite.json", JSON.pretty_generate(
      "all" => {
        "sourceCodeDir" => js_destination_path,
        "ssrEntrypoint" => "~/entrypoints/inertia.{js,ts,jsx,tsx}",
        "watchAdditionalPaths" => []
      },
      "development" => {"autoBuild" => true, "skipProxy" => true, "publicOutputDir" => "vite-dev", "port" => 3036},
      "test" => {"autoBuild" => true, "publicOutputDir" => "vite-test", "port" => 3037}
    ) + "\n"
  end

  # Add .gitignore entries
  if File.exist?(".gitignore")
    append_with_blank_line.(".gitignore", <<~GITIGNORE)
      # Vite
      /public/vite*
      /ssr
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
  say "  #{(vite_gem == "vite_rails") ? "Vite Rails" : "Rails Vite"} already installed, skipping", :green

  # vite_rails builds SSR from its own entry (ssr/ssr.js unless set);
  # point it at the Inertia entrypoint
  if vite_gem == "vite_rails"
    update_json_file.("config/vite.json") do |config|
      (config["all"] ||= {})["ssrEntrypoint"] ||= "~/entrypoints/inertia.{js,ts,jsx,tsx}"
    end
  end
end
