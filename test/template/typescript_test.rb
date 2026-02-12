# frozen_string_literal: true

require_relative "../test_helper"

class TypescriptReactTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_typescript = true
    js_ext = "ts"
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "typescript" %>
  CODE

  def test_creates_tsconfig_files
    run_generator do |output|
      assert_file "tsconfig.json"
      assert_file "tsconfig.app.json"
      assert_file "tsconfig.node.json"
      assert_line_printed output, "Setting up TypeScript"
    end
  end

  def test_creates_type_definitions
    run_generator do
      assert_file "app/javascript/types/vite-env.d.ts"
      assert_file "app/javascript/types/globals.d.ts"
      assert_file "app/javascript/types/index.ts"
      assert_file_contains "app/javascript/types/globals.d.ts", "@inertiajs/core"
    end
  end

  def test_adds_check_script
    run_generator do
      pkg = JSON.parse(File.read(File.join(destination, "package.json")))
      assert_includes pkg.dig("scripts", "check"), "tsc -p tsconfig.app.json"
    end
  end
end

class TypescriptVueTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "vue"
    use_typescript = true
    js_ext = "ts"
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "typescript" %>
  CODE

  def test_creates_tsconfig_files
    run_generator do
      assert_file "tsconfig.json"
      assert_file "tsconfig.app.json"
      assert_file "tsconfig.node.json"
    end
  end

  def test_adds_vue_tsc_check_script
    run_generator do
      pkg = JSON.parse(File.read(File.join(destination, "package.json")))
      assert_includes pkg.dig("scripts", "check"), "vue-tsc"
    end
  end
end

class TypescriptSvelteTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "svelte"
    use_typescript = true
    js_ext = "ts"
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "typescript" %>
  CODE

  def test_creates_tsconfig_files
    run_generator do
      assert_file "tsconfig.json"
      assert_file "tsconfig.node.json"
    end
  end

  def test_adds_svelte_check_script
    run_generator do
      pkg = JSON.parse(File.read(File.join(destination, "package.json")))
      assert_includes pkg.dig("scripts", "check"), "svelte-check"
    end
  end
end

class TypescriptDisabledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_typescript = false
    js_ext = "js"
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "typescript" %>
  CODE

  def test_skips_when_disabled
    run_generator do
      refute_file "tsconfig.json"
      refute_file "app/javascript/types/vite-env.d.ts"
    end
  end
end
