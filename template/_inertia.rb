# ─── Inertia Core Setup ──────────────────────────────────────────────

say "📦 Setting up Inertia...", :cyan

# Add inertia_rails to Gemfile (installed in _finalize.rb with single bundle install)
rails_vite_anchor = "gem \"rails_vite\" # Vite integration [https://github.com/skryukov/rails_vite]\n"
unless gem_in_gemfile.("inertia_rails")
  if File.exist?("Gemfile") && File.read("Gemfile").include?(rails_vite_anchor)
    insert_into_file "Gemfile",
      "\n# The Rails adapter for Inertia.js [https://inertia-rails.dev]\ngem \"inertia_rails\", \"~> 3.21\"\n",
      after: rails_vite_anchor
  else
    append_to_file "Gemfile", <<~GEM
      gem "inertia_rails", "~> 3.21" # The Rails adapter for Inertia.js [https://inertia-rails.dev]
    GEM
  end
end

# Add Inertia Vite plugin (shared across all frameworks)
npm_dev_packages << "@inertiajs/vite@^3.0"

# Add framework-specific packages and plugins
case framework
when "react"
  npm_packages.push("@inertiajs/react@^3.0", "react", "react-dom")
  npm_dev_packages.push("@vitejs/plugin-react", "@rolldown/plugin-babel", "babel-plugin-react-compiler", "@babel/core")
  vite_plugins << { import: "import react, { reactCompilerPreset } from '@vitejs/plugin-react'", call: "react()" }
  vite_plugins << { import: "import babel from '@rolldown/plugin-babel'", call: "babel({ presets: [reactCompilerPreset()] })" }
when "vue"
  npm_packages.push("@inertiajs/vue3@^3.0", "vue")
  npm_dev_packages.push("@vitejs/plugin-vue", "vite-plugin-vue-devtools")
  vite_plugins << { import: "import vue from '@vitejs/plugin-vue'", call: "vue()" }
  vite_plugins << { import: "import vueDevTools from 'vite-plugin-vue-devtools'", call: "vueDevTools({ appendTo: 'inertia.#{js_ext}' })" }
when "svelte"
  npm_packages.push("@inertiajs/svelte@^3.0", "svelte@5")
  npm_dev_packages << "@sveltejs/vite-plugin-svelte"
  vite_plugins << { import: "import { svelte } from '@sveltejs/vite-plugin-svelte'", call: "svelte()" }
  file "svelte.config.js", <<~JS
    import { vitePreprocess } from '@sveltejs/vite-plugin-svelte'

    export default {
      preprocess: vitePreprocess(),
    }
  JS
end

# Create initializer
file "config/initializers/inertia_rails.rb", <%= code("shared/initializer.rb.tt") %>

# Create InertiaController
file "app/controllers/inertia_controller.rb", <%= code("shared/inertia_controller.rb") %>

# Modify application layout
layout_file = "app/views/layouts/application.html.erb"
if File.exist?(layout_file)
  # Add vite_tags with all entrypoints in a single call
  unless File.read(layout_file).include?("vite_tags")
    inertia_entrypoint = case framework
      when "react" then "inertia.#{component_ext}"
      else "inertia.#{js_ext}"
    end

    vite_entries = []
    vite_entries << "\"application.css\"" if use_tailwind
    vite_entries << "\"#{inertia_entrypoint}\""

    insert_into_file layout_file,
      "    <%%= vite_tags #{vite_entries.join(", ")} %>\n    <%%= inertia_ssr_head %>\n",
      before: "  </head>"
  end

  # Add data-inertia to title tag (not for Svelte)
  unless framework == "svelte"
    gsub_file layout_file, /<title>/, "<title data-inertia>"
  end
end

# Run the Inertia SSR Node process alongside Puma (inert until config.ssr_enabled is
# true, so apps stay SSR-ready whether or not SSR is enabled at generation time).
puma_file = "config/puma.rb"
if File.exist?(puma_file)
  unless File.read(puma_file).include?("plugin :inertia_ssr")
    append_with_blank_line.(puma_file,
      "# Run the Inertia SSR process alongside Puma when config.ssr_enabled is true.\nplugin :inertia_ssr\n")
  end
else
  say "  ⚠ config/puma.rb not found — add `plugin :inertia_ssr` to run SSR in production.", :yellow
end

say "  Inertia core configured ✓", :green
