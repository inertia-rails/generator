# ─── Inertia Core Setup ──────────────────────────────────────────────

say "📦 Setting up Inertia...", :cyan

# Add inertia_rails to Gemfile (installed in _finalize.rb with single bundle install)
unless gem_in_gemfile.("inertia_rails")
  append_to_file "Gemfile", <<~GEM
    gem "inertia_rails", "~> 3.19" # Inertia.js adapter [https://inertia-rails.dev]
  GEM
end

# Add Inertia Vite plugin (shared across all frameworks)
npm_dev_packages << "@inertiajs/vite@^3.0"

# Add framework-specific packages and plugins
case framework
when "react"
  npm_packages.push("@inertiajs/react@^3.0", "react", "react-dom")
  npm_dev_packages.push("@vitejs/plugin-react", "@rolldown/plugin-babel", "babel-plugin-react-compiler")
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

say "  Inertia core configured ✓", :green
