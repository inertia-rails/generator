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
    app_title = "Test App"
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
    end
  end

  def test_replaces_title_with_inertia_meta_tags
    run_generator do
      layout = File.read(File.join(destination, "app/views/layouts/application.html.erb"))
      assert_includes layout, '    <%= inertia_meta_tags(default_title: "Test") %>'
      refute_includes layout, "<title>"
    end
  end

  def test_initializer_enables_v3_server_options
    run_generator do
      assert_file_contains "config/initializers/inertia_rails.rb", "config.server_head = true"
      assert_file_contains "config/initializers/inertia_rails.rb", "config.convert_fragment_redirects = true"
    end
  end

  def test_requires_gem_and_client_versions_with_server_head
    run_generator do
      assert_file_contains "tmp_npm.txt", "@inertiajs/react@^3.5"
      assert_file_contains "tmp_dev.txt", "@inertiajs/vite@^3.5"
      assert_file_contains "Gemfile", '"inertia_rails", "~> 3.23"'
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
    app_title = "Test App"
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

  def test_replaces_title_with_inertia_meta_tags
    run_generator do
      assert_file_contains "app/views/layouts/application.html.erb", 'inertia_meta_tags(default_title: "Test")'
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
    app_title = "Test App"
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

  def test_replaces_title_with_inertia_meta_tags
    run_generator do
      assert_file_contains "app/views/layouts/application.html.erb", 'inertia_meta_tags(default_title: "Test")'
    end
  end

  def test_uses_vite_tags
    run_generator do
      assert_file_contains "app/views/layouts/application.html.erb", 'vite_tags "inertia.js"'
    end
  end
end

class InertiaLayoutTitleTest < GeneratorTestCase
  PREAMBLE = <<~CODE
    require "json"
    framework = "react"
    use_typescript = true
    use_ssr = false
    use_tailwind = false
    use_starter_kit = false
    js_ext = "ts"
    component_ext = "tsx"
    js_destination_path = "app/javascript"
    app_title = "Test App"
    npm_packages = []
    npm_dev_packages = []
    vite_plugins = []
    gem_in_gemfile = ->(name) { false }
    add_gem = ->(name, comment: nil, group: nil) {}
  CODE

  # The stock Rails layout: an ERB expression with a fallback
  template <<~CODE
    #{PREAMBLE}
    file "app/views/layouts/application.html.erb", <<~HTML
      <html>
        <head>
          <title><%%= content_for(:title) || "Myapp" %></title>
          <meta name="viewport" content="width=device-width,initial-scale=1">
        </head>
      </html>
    HTML
    <%= include "inertia" %>
  CODE

  def test_keeps_the_layout_title_expression_as_default_title
    run_generator do
      layout = File.read(File.join(destination, "app/views/layouts/application.html.erb"))
      assert_includes layout, '    <%= inertia_meta_tags(default_title: content_for(:title) || "Myapp") %>'
      refute_includes layout, "<title>"
      assert_includes layout, '<meta name="viewport"'
    end
  end
end

class InertiaLayoutEmptyTitleTest < GeneratorTestCase
  template <<~CODE
    #{InertiaLayoutTitleTest::PREAMBLE}
    file "app/views/layouts/application.html.erb", <<~HTML
      <html>
        <head>
          <title></title>
        </head>
      </html>
    HTML
    <%= include "inertia" %>
  CODE

  def test_falls_back_to_the_app_title
    run_generator do
      assert_file_contains "app/views/layouts/application.html.erb", 'inertia_meta_tags(default_title: "Test App")'
    end
  end
end
