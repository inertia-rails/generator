# frozen_string_literal: true

require_relative "../test_helper"

class ExamplePageReactTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    auth_strategy = "none"
    use_starter_kit = false
    use_typescript = true
    use_tailwind = false
    component_ext = "tsx"
    js_destination_path = "app/javascript"
    <%= include "example_page" %>
  CODE

  def test_creates_controller
    run_generator do |output|
      assert_file "app/controllers/home_controller.rb"
      assert_file_contains "app/controllers/home_controller.rb", "class HomeController < InertiaController"
      assert_line_printed output, "Creating welcome page"
    end
  end

  def test_creates_page_component
    run_generator do
      assert_file "app/javascript/pages/home/index.tsx"
    end
  end

  def test_adds_root_route
    run_generator do
      assert_file_contains "config/routes.rb", 'root "home#index"'
    end
  end
end

class ExamplePageVueTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "vue"
    auth_strategy = "none"
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    component_ext = "vue"
    js_destination_path = "app/javascript"
    <%= include "example_page" %>
  CODE

  def test_creates_vue_page_component
    run_generator do
      assert_file "app/javascript/pages/home/index.vue"
    end
  end
end

class ExamplePageSvelteTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "svelte"
    auth_strategy = "none"
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    component_ext = "svelte"
    js_destination_path = "app/javascript"
    <%= include "example_page" %>
  CODE

  def test_creates_svelte_page_component
    run_generator do
      assert_file "app/javascript/pages/home/index.svelte"
    end
  end
end

class ExamplePageSkippedWithStarterKitTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_starter_kit = true
    use_typescript = true
    use_tailwind = false
    component_ext = "tsx"
    js_destination_path = "app/javascript"
    <%= include "example_page" %>
  CODE

  def test_skips_when_starter_kit
    run_generator do
      refute_file "app/controllers/home_controller.rb"
      refute_file "app/javascript/pages/home/index.tsx"
    end
  end
end
