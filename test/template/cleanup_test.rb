# frozen_string_literal: true

require_relative "../test_helper"

class CleanupConflictImportmapTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = nil
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    app_name = "test_app"
    #{GEM_IN_GEMFILE}
    #{REMOVE_GEM}
    file "config/importmap.rb", "pin 'application'"
    file "bin/importmap", "#!/usr/bin/env ruby"
    <%= include "detect" %>
    <%= include "cleanup" %>
  CODE

  def test_removes_importmap_on_fresh_app
    prepare_dummy do
      File.write("Gemfile", "gem 'importmap-rails'\n", mode: "a")
    end

    run_generator do |output|
      assert_line_printed output, "Removing importmap-rails"
      gemfile = File.read(File.join(destination, "Gemfile"))
      refute gemfile.include?("importmap-rails"), "importmap-rails should be removed from Gemfile"
    end
  end
end

class CleanupConflictTurboTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = nil
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    app_name = "test_app"
    #{GEM_IN_GEMFILE}
    #{REMOVE_GEM}
    <%= include "detect" %>
    <%= include "cleanup" %>
  CODE

  def test_removes_turbo_rails_on_fresh_app
    prepare_dummy do
      File.write("Gemfile", "gem 'turbo-rails'\ngem 'stimulus-rails'\n", mode: "a")
    end

    run_generator do |output|
      assert_line_printed output, "Removing turbo-rails"
      assert_line_printed output, "Removing stimulus-rails"
      gemfile = File.read(File.join(destination, "Gemfile"))
      refute gemfile.include?("turbo-rails"), "turbo-rails should be removed from Gemfile"
      refute gemfile.include?("stimulus-rails"), "stimulus-rails should be removed from Gemfile"
    end
  end
end

class CleanupConflictStylesheetTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = nil
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    app_name = "test_app"
    #{GEM_IN_GEMFILE}
    #{REMOVE_GEM}
    file "app/views/layouts/application.html.erb", <<~HTML
      <html>
        <head>
          <%%= stylesheet_link_tag "application" %>
        </head>
      </html>
    HTML
    file "app/assets/stylesheets/application.css", "body { color: red; }"
    <%= include "detect" %>
    <%= include "cleanup" %>
  CODE

  def test_removes_stylesheet_link_tag
    run_generator do
      layout = File.read(File.join(destination, "app/views/layouts/application.html.erb"))
      refute layout.include?("stylesheet_link_tag"), "stylesheet_link_tag should be removed"
    end
  end
end
