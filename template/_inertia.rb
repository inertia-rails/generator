# ─── Inertia Core Setup ──────────────────────────────────────────────

say "📦 Setting up Inertia...", :cyan

# Add inertia_rails to Gemfile (installed in _finalize.rb with single bundle install)
vite_gem_anchor = /^gem "#{vite_gem}".*\n/
unless gem_in_gemfile.("inertia_rails")
  if File.exist?("Gemfile") && File.read("Gemfile").match?(vite_gem_anchor)
    insert_into_file "Gemfile",
      "\n# The Rails adapter for Inertia.js [https://inertia-rails.dev]\ngem \"inertia_rails\", \"~> 3.23\"\n",
      after: vite_gem_anchor
  else
    append_to_file "Gemfile", <<~GEM
      gem "inertia_rails", "~> 3.23" # The Rails adapter for Inertia.js [https://inertia-rails.dev]
    GEM
  end
end

# Add Inertia Vite plugin (shared across all frameworks)
npm_dev_packages << "@inertiajs/vite@^3.5"

# Add framework-specific packages and plugins
case framework
when "react"
  npm_packages.push("@inertiajs/react@^3.5", "react", "react-dom")
  npm_dev_packages.push("@vitejs/plugin-react", "@rolldown/plugin-babel", "babel-plugin-react-compiler", "@babel/core")
  vite_plugins << { import: "import react, { reactCompilerPreset } from '@vitejs/plugin-react'", call: "react()" }
  vite_plugins << { import: "import babel from '@rolldown/plugin-babel'", call: "babel({ presets: [reactCompilerPreset()] })" }
when "vue"
  npm_packages.push("@inertiajs/vue3@^3.5", "vue")
  npm_dev_packages.push("@vitejs/plugin-vue", "vite-plugin-vue-devtools")
  vite_plugins << { import: "import vue from '@vitejs/plugin-vue'", call: "vue()" }
  vite_plugins << { import: "import vueDevTools from 'vite-plugin-vue-devtools'", call: "vueDevTools({ appendTo: 'inertia.#{js_ext}' })" }
when "svelte"
  npm_packages.push("@inertiajs/svelte@^3.5", "svelte@5")
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
  inertia_entrypoint = case framework
    when "react" then "\"inertia.#{component_ext}\""
    else "\"inertia.#{js_ext}\""
  end

  # rails_vite: one vite_tags call with all entrypoints.
  # vite_rails: one tag helper per kind of asset.
  # Each tag comes with the text that tells it is already in the layout, so
  # an app with Vite set up only gets what it lacks.
  vite_head_tags =
    if vite_gem == "vite_rails"
      entry_helper = use_typescript ? "vite_typescript_tag" : "vite_javascript_tag"
      [
        (["vite_react_refresh_tag", "vite_react_refresh_tag"] if framework == "react"),
        ["vite_client_tag", "vite_client_tag"],
        (["vite_stylesheet_tag", "vite_stylesheet_tag \"application.css\""] if use_tailwind),
        [inertia_entrypoint, "#{entry_helper} #{inertia_entrypoint}"]
      ].compact
    else
      vite_entries = [("\"application.css\"" if use_tailwind), inertia_entrypoint].compact
      [[inertia_entrypoint, "vite_tags #{vite_entries.join(", ")}"]]
    end
  vite_head_tags << ["inertia_ssr_head", "inertia_ssr_head"]

  layout = File.read(layout_file)
  missing_head_tags = vite_head_tags.reject { |present_as, _tag| layout.include?(present_as) }
  if missing_head_tags.any?
    insert_into_file layout_file,
      missing_head_tags.map { |_present_as, tag| "    <%%= #{tag} %>\n" }.join,
      before: "  </head>"
  end

  # Let Inertia own the <title>: swap it for inertia_meta_tags, keeping the
  # layout's current title as the fallback for pages that don't set one
  if (title_tag = File.read(layout_file).match(%r{^(\s*)<title>(.*)</title>\s*\n}))
    title_content = title_tag[2].strip
    default_title =
      if (erb = title_content.match(/\A<%%=\s*(.+?)\s*%>\z/))
        erb[1]
      elsif title_content.empty?
        app_title.inspect
      else
        title_content.inspect
      end
    gsub_file layout_file, title_tag[0],
      "#{title_tag[1]}<%%= inertia_meta_tags(default_title: #{default_title}) %>\n"
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
