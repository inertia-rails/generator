# frozen_string_literal: true

require_relative "../test_helper"

class InertiaReactTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_typescript = true
    use_ssr = false
    use_tailwind = false
    use_starter_kit = false
    js_ext = "ts"
    component_ext = "tsx"
    js_destination_path = "app/javascript"
    npm_packages = []
    npm_dev_packages = []
    vite_plugins = []
    gem_in_gemfile = ->(name) { false }
    add_gem = ->(name, comment: nil, group: nil) {}
    file "app/views/layouts/application.html.erb", <<~HTML
      <html>
        <head>
          <title>Test</title>
        </head>
        <body>
        </body>
      </html>
    HTML
    <%= include "inertia" %>
    file "tmp_npm.txt", npm_packages.sort.join(",")
    file "tmp_dev.txt", npm_dev_packages.sort.join(",")
    file "tmp_plugins.txt", vite_plugins.map { |p| p[:call] }.join(",")

  CODE

  def test_adds_npm_packages
    run_generator do
      assert_file_contains "tmp_npm.txt", "@inertiajs/react"
      assert_file_contains "tmp_npm.txt", "react-dom"
      assert_file_contains "tmp_dev.txt", "@vitejs/plugin-react"
      assert_file_contains "tmp_dev.txt", "@inertiajs/vite"
    end
  end

  def test_adds_vite_plugin
    run_generator do
      assert_file_contains "tmp_plugins.txt", "react()"
      assert_file_contains "tmp_plugins.txt", "babel({ presets: [reactCompilerPreset()] })"
    end
  end

  def test_creates_initializer
    run_generator do
      assert_file "config/initializers/inertia_rails.rb"
      assert_file_contains "config/initializers/inertia_rails.rb", "InertiaRails.configure"
      assert_file_contains "config/initializers/inertia_rails.rb", "RailsVite.digest"
    end
  end

  def test_creates_controller
    run_generator do
      assert_file "app/controllers/inertia_controller.rb"
      assert_file_contains "app/controllers/inertia_controller.rb", "class InertiaController"
    end
  end

  def test_modifies_layout
    run_generator do
      assert_file_contains "app/views/layouts/application.html.erb", 'vite_tags "inertia.tsx"'
      assert_file_contains "app/views/layouts/application.html.erb", "inertia_ssr_head"
      assert_file_contains "app/views/layouts/application.html.erb", "data-inertia"
    end
  end
end

class InertiaVueTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "vue"
    use_typescript = true
    use_ssr = false
    use_tailwind = false
    use_starter_kit = false
    js_ext = "ts"
    component_ext = "vue"
    js_destination_path = "app/javascript"
    npm_packages = []
    npm_dev_packages = []
    vite_plugins = []
    gem_in_gemfile = ->(name) { false }
    add_gem = ->(name, comment: nil, group: nil) {}
    file "app/views/layouts/application.html.erb", <<~HTML
      <html>
        <head>
          <title>Test</title>
        </head>
        <body>
        </body>
      </html>
    HTML
    <%= include "inertia" %>
    file "tmp_npm.txt", npm_packages.sort.join(",")
    file "tmp_dev.txt", npm_dev_packages.sort.join(",")
    file "tmp_plugins.txt", vite_plugins.map { |p| p[:call] }.join(",")

  CODE

  def test_adds_npm_packages
    run_generator do
      assert_file_contains "tmp_npm.txt", "@inertiajs/vue3"
      assert_file_contains "tmp_npm.txt", "vue"
      assert_file_contains "tmp_dev.txt", "@vitejs/plugin-vue"
      assert_file_contains "tmp_dev.txt", "@inertiajs/vite"
    end
  end

  def test_adds_vite_plugin
    run_generator do
      assert_file_contains "tmp_plugins.txt", "vue()"
    end
  end

  def test_uses_vite_tags
    run_generator do
      assert_file_contains "app/views/layouts/application.html.erb", 'vite_tags "inertia.ts"'
    end
  end

  def test_adds_data_inertia_to_title
    run_generator do
      assert_file_contains "app/views/layouts/application.html.erb", "data-inertia"
    end
  end
end

class InertiaSvelteTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "svelte"
    use_typescript = false
    use_ssr = false
    use_tailwind = false
    use_starter_kit = false
    js_ext = "js"
    component_ext = "svelte"
    js_destination_path = "app/javascript"
    npm_packages = []
    npm_dev_packages = []
    vite_plugins = []
    gem_in_gemfile = ->(name) { false }
    add_gem = ->(name, comment: nil, group: nil) {}
    file "app/views/layouts/application.html.erb", <<~HTML
      <html>
        <head>
          <title>Test</title>
        </head>
        <body>
        </body>
      </html>
    HTML
    <%= include "inertia" %>
    file "tmp_npm.txt", npm_packages.sort.join(",")
    file "tmp_dev.txt", npm_dev_packages.sort.join(",")
    file "tmp_plugins.txt", vite_plugins.map { |p| p[:call] }.join(",")

  CODE

  def test_adds_npm_packages
    run_generator do
      assert_file_contains "tmp_npm.txt", "@inertiajs/svelte"
      assert_file_contains "tmp_npm.txt", "svelte@5"
      assert_file_contains "tmp_dev.txt", "@sveltejs/vite-plugin-svelte"
      assert_file_contains "tmp_dev.txt", "@inertiajs/vite"
    end
  end

  def test_adds_vite_plugin
    run_generator do
      assert_file_contains "tmp_plugins.txt", "svelte()"
    end
  end

  def test_creates_svelte_config
    run_generator do
      assert_file "svelte.config.js"
      assert_file_contains "svelte.config.js", "vitePreprocess"
    end
  end

  def test_no_data_inertia_on_title
    run_generator do
      layout = File.read(File.join(destination, "app/views/layouts/application.html.erb"))
      refute layout.include?("data-inertia"), "Svelte should not add data-inertia to title"
    end
  end

  def test_uses_vite_tags
    run_generator do
      assert_file_contains "app/views/layouts/application.html.erb", 'vite_tags "inertia.js"'
    end
  end
end
