# frozen_string_literal: true

require_relative "../test_helper"

class ViteAlreadyInstalledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    app_name = "test_app"
    vite_installed = true
    use_typescript = false
    js_destination_path = "app/javascript"
    package_manager = "npm"
    npm_dev_packages = []
    gem_in_gemfile = ->(name) { true }
    #{NOOP_ADD_GEM}
    #{UPDATE_PACKAGE_JSON}
    #{APPEND_WITH_BLANK_LINE}
    <%= include "vite" %>
  CODE

  def test_skips_when_already_installed
    run_generator do |output|
      assert_line_printed output, "already installed"
    end
  end
end

class ViteFreshInstallTest < GeneratorTestCase
  template <<~'CODE'
    require "json"
    app_name = "test_app"
    vite_installed = false
    use_typescript = true
    js_destination_path = "app/javascript"
    package_manager = "npm"
    npm_dev_packages = []
    gem_in_gemfile = ->(name) { false }
    add_gem = ->(name, comment: nil, group: nil) {
      append_to_file "Gemfile", "gem \"#{name}\"\n"
    }
    update_package_json = ->(&block) {
      return unless File.exist?("package.json")
      pkg = JSON.parse(File.read("package.json"))
      block.call(pkg)
      File.write("package.json", JSON.pretty_generate(pkg) + "\n")
    }
    append_with_blank_line = ->(path, content) {
      append_to_file path, "\n" unless File.read(path).end_with?("\n\n")
      append_to_file path, content
    }
    <%= include "vite" %>
    file "tmp_dev_pkgs.txt", npm_dev_packages.join(",")
  CODE

  def test_creates_package_json_when_missing
    run_generator do |output|
      assert_line_printed output, "Creating package.json"
      assert_file "package.json"
    end
  end

  def test_creates_entrypoints_directory
    run_generator do
      assert File.directory?(File.join(destination, "app/javascript/entrypoints")),
        "app/javascript/entrypoints directory should exist"
    end
  end

  def test_adds_rails_vite_plugin_to_dev_packages
    run_generator do
      assert_file_contains "tmp_dev_pkgs.txt", "rails-vite-plugin"
      assert_file_contains "tmp_dev_pkgs.txt", "vite@^8"
    end
  end

  def test_adds_gitignore_entries
    run_generator do
      assert_file_contains ".gitignore", "/public/vite"
      assert_file_contains ".gitignore", "node_modules"
      assert_file_contains ".gitignore", "*.local"
    end
  end

  def test_adds_rails_vite_gem
    run_generator do
      assert_file_contains "Gemfile", 'gem "rails_vite"'
    end
  end

  def test_adds_vite_override_to_package_json
    run_generator do
      assert_file_contains "package.json", "overrides"
    end
  end
end
