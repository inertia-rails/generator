# frozen_string_literal: true

require_relative "../test_helper"

class DetectFreshAppTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = nil
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    importmap_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "PM=\#{package_manager}"
    say "FW=\#{framework_detected || "none"}"
    say "TS=\#{typescript_detected}"
    say "TW=\#{tailwind_detected}"
    say "VITE=\#{vite_installed}"
  CODE

  def test_detects_fresh_app
    run_generator do |output|
      assert_line_printed output, "Detected: fresh Rails app"
    end
  end

  def test_default_package_manager_is_npm
    run_generator do |output|
      assert_line_printed output, "PM=npm"
    end
  end

  def test_skips_detection_on_fresh_app
    run_generator do |output|
      assert_line_printed output, "FW=none"
      assert_line_printed output, "VITE=false"
      assert_line_printed output, "TS=false"
      assert_line_printed output, "TW=false"
    end
  end

  def test_does_not_create_package_json
    run_generator do |output|
      refute_includes output, "Creating package.json"
    end
  end

  def test_detection_completes
    run_generator do |output|
      assert_line_printed output, "Detection complete"
    end
  end
end

class DetectReactFrameworkTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = false
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "package.json", '{"dependencies":{"react":"^18.0.0"}}'
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "FW=\#{framework_detected || "none"}"
  CODE

  def test_detects_react
    run_generator do |output|
      assert_line_printed output, "FW=react"
    end
  end
end

class DetectVueFrameworkTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = false
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "package.json", '{"dependencies":{"vue":"^3.0.0"}}'
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "FW=\#{framework_detected || "none"}"
  CODE

  def test_detects_vue
    run_generator do |output|
      assert_line_printed output, "FW=vue"
    end
  end
end

class DetectSvelteFrameworkTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = false
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "package.json", '{"dependencies":{"svelte":"^5.0.0"}}'
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "FW=\#{framework_detected || "none"}"
  CODE

  def test_detects_svelte
    run_generator do |output|
      assert_line_printed output, "FW=svelte"
    end
  end
end

class DetectTypescriptTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = false
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "tsconfig.json", "{}"
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "TS=\#{typescript_detected}"
  CODE

  def test_detects_typescript
    run_generator do |output|
      assert_line_printed output, "TS=true"
    end
  end
end

class DetectTailwindTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = false
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "package.json", '{"dependencies":{"tailwindcss":"^4.0.0"}}'
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "TW=\#{tailwind_detected}"
  CODE

  def test_detects_tailwind
    run_generator do |output|
      assert_line_printed output, "TW=true"
    end
  end
end

class DetectViteInstalledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = false
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "vite.config.ts", "export default {}"
    append_to_file "Gemfile", %(gem "rails_vite"\n)
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "VITE=\#{vite_installed}"
  CODE

  def test_detects_vite
    run_generator do |output|
      assert_line_printed output, "VITE=true"
    end
  end
end

class DetectPackageManagerBunTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = nil
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "bun.lockb", ""
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "PM=\#{package_manager}"
  CODE

  def test_detects_bun
    run_generator do |output|
      assert_line_printed output, "PM=bun"
    end
  end
end

class DetectPackageManagerYarnTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = nil
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "yarn.lock", ""
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "PM=\#{package_manager}"
  CODE

  def test_detects_yarn
    run_generator do |output|
      assert_line_printed output, "PM=yarn"
    end
  end
end

class DetectPackageManagerPnpmTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = nil
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "pnpm-lock.yaml", ""
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "PM=\#{package_manager}"
  CODE

  def test_detects_pnpm
    run_generator do |output|
      assert_line_printed output, "PM=pnpm"
    end
  end
end

class DetectJsDestinationFrontendTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = false
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    js_destination_detected = nil
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "app/frontend/entrypoints/.keep", ""
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "JSDIR=\#{js_destination_detected || 'none'}"
  CODE

  def test_detects_app_frontend
    run_generator do |output|
      assert_line_printed output, "JSDIR=app/frontend"
      assert_line_printed output, "Frontend dir: app/frontend"
    end
  end
end

class DetectJsDestinationJavascriptTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = false
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    js_destination_detected = nil
    package_manager = "npm"
    db_adapter = "sqlite3"
    file "app/javascript/entrypoints/.keep", ""
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "JSDIR=\#{js_destination_detected || 'none'}"
  CODE

  def test_detects_app_javascript
    run_generator do |output|
      assert_line_printed output, "JSDIR=app/javascript"
    end
  end
end

class DetectJsDestinationDefaultTest < GeneratorTestCase
  template <<~CODE
    require "json"
    fresh_app = false
    vite_installed = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    js_destination_detected = nil
    package_manager = "npm"
    db_adapter = "sqlite3"
    importmap_detected = false
    vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
    say "JSDIR=\#{js_destination_detected || 'none'}"
  CODE

  def test_defaults_to_none_when_no_existing_dir
    run_generator do |output|
      assert_line_printed output, "JSDIR=none"
      assert_line_printed output, "Frontend dir: app/javascript (default)"
    end
  end
end

class DetectJsbundlingBlockerTest < GeneratorTestCase
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
    #{GEM_IN_GEMFILE}
    <%= include "detect" %>
  CODE

  def test_exits_when_jsbundling_detected
    prepare_dummy do
      File.write("Gemfile", "gem 'jsbundling-rails'\n", mode: "a")
    end

    assert_raises(SystemExit) do
      run_generator {}
    end
  end
end
