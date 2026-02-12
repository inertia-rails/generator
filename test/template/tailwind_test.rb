# frozen_string_literal: true

require_relative "../test_helper"

class TailwindEnabledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    use_tailwind = true
    tailwind_detected = false
    js_destination_path = "app/javascript"
    npm_packages = []
    npm_dev_packages = []
    vite_plugins = []
    <%= include "tailwind" %>
  CODE

  def test_creates_css_entrypoint
    run_generator do |output|
      assert_file "app/javascript/entrypoints/application.css"
      assert_file_contains "app/javascript/entrypoints/application.css", "@import 'tailwindcss'"
      assert_line_printed output, "Setting up Tailwind CSS v4"
    end
  end
end

class TailwindAlreadyInstalledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    use_tailwind = true
    tailwind_detected = true
    js_destination_path = "app/javascript"
    npm_packages = []
    npm_dev_packages = []
    vite_plugins = []
    <%= include "tailwind" %>
  CODE

  def test_skips_when_already_detected
    run_generator do |output|
      refute_file "app/javascript/entrypoints/application.css"
      assert_line_printed output, "Tailwind CSS already installed"
    end
  end
end

class TailwindDisabledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    use_tailwind = false
    tailwind_detected = false
    js_destination_path = "app/javascript"
    npm_packages = []
    npm_dev_packages = []
    vite_plugins = []
    <%= include "tailwind" %>
  CODE

  def test_skips_when_disabled
    run_generator do
      refute_file "app/javascript/entrypoints/application.css"
    end
  end
end
