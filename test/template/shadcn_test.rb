# frozen_string_literal: true

require_relative "../test_helper"

class ShadcnReactTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_shadcn = true
    use_typescript = true
    js_ext = "ts"
    use_starter_kit = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    post_install_commands = []
    eslint_ignores = []
    <%= include "shadcn" %>
  CODE

  def test_creates_components_json
    run_generator do |output|
      assert_file "components.json"
      assert_file_contains "components.json", "ui.shadcn.com/schema.json"
      assert_file_contains "components.json", '"tsx": true'
      assert_line_printed output, "Setting up shadcn/ui"
    end
  end

  def test_creates_utils_file
    run_generator do
      assert_file "app/javascript/lib/utils.ts"
      assert_file_contains "app/javascript/lib/utils.ts", "clsx"
      assert_file_contains "app/javascript/lib/utils.ts", "twMerge"
    end
  end
end

class ShadcnReactJsTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_shadcn = true
    use_typescript = false
    js_ext = "js"
    use_starter_kit = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    post_install_commands = []
    eslint_ignores = []
    <%= include "shadcn" %>
  CODE

  def test_creates_components_json_with_tsx_false
    run_generator do
      assert_file "components.json"
      assert_file_contains "components.json", '"tsx": false'
    end
  end

  def test_creates_js_utils_file
    run_generator do
      assert_file "app/javascript/lib/utils.js"
      assert_file_contains "app/javascript/lib/utils.js", "clsx"
      refute_file "app/javascript/lib/utils.ts"
    end
  end

  def test_creates_jsconfig
    run_generator do
      assert_file "jsconfig.json"
      assert_file_contains "jsconfig.json", "@/*"
    end
  end
end

class ShadcnVueTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "vue"
    use_shadcn = true
    use_typescript = true
    js_ext = "ts"
    use_starter_kit = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    post_install_commands = []
    eslint_ignores = []
    <%= include "shadcn" %>
  CODE

  def test_creates_components_json
    run_generator do
      assert_file "components.json"
      assert_file_contains "components.json", "shadcn-vue.com/schema.json"
      assert_file_contains "components.json", '"typescript": true'
    end
  end

  def test_creates_utils_file
    run_generator do
      assert_file "app/javascript/lib/utils.ts"
      assert_file_contains "app/javascript/lib/utils.ts", "clsx"
      assert_file_contains "app/javascript/lib/utils.ts", "twMerge"
    end
  end
end

class ShadcnVueJsTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "vue"
    use_shadcn = true
    use_typescript = false
    js_ext = "js"
    use_starter_kit = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    post_install_commands = []
    eslint_ignores = []
    <%= include "shadcn" %>
  CODE

  def test_creates_components_json_with_typescript_false
    run_generator do
      assert_file "components.json"
      assert_file_contains "components.json", '"typescript": false'
    end
  end

  def test_creates_js_utils_file
    run_generator do
      assert_file "app/javascript/lib/utils.js"
      refute_file "app/javascript/lib/utils.ts"
    end
  end

  def test_creates_jsconfig
    run_generator do
      assert_file "jsconfig.json"
    end
  end
end

class ShadcnSvelteTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "svelte"
    use_shadcn = true
    use_typescript = true
    js_ext = "ts"
    use_starter_kit = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    post_install_commands = []
    eslint_ignores = []
    <%= include "shadcn" %>
  CODE

  def test_creates_components_json
    run_generator do
      assert_file "components.json"
      assert_file_contains "components.json", "shadcn-svelte.com/schema.json"
      assert_file_contains "components.json", '"typescript": true'
    end
  end

  def test_creates_utils_file
    run_generator do
      assert_file "app/javascript/utils.ts"
      assert_file_contains "app/javascript/utils.ts", "clsx"
      assert_file_contains "app/javascript/utils.ts", "twMerge"
    end
  end
end

class ShadcnSvelteJsTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "svelte"
    use_shadcn = true
    use_typescript = false
    js_ext = "js"
    use_starter_kit = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    post_install_commands = []
    eslint_ignores = []
    <%= include "shadcn" %>
  CODE

  def test_creates_components_json_with_typescript_false
    run_generator do
      assert_file "components.json"
      assert_file_contains "components.json", '"typescript": false'
    end
  end

  def test_creates_js_utils_file
    run_generator do
      assert_file "app/javascript/utils.js"
      refute_file "app/javascript/utils.ts"
    end
  end

  def test_creates_jsconfig
    run_generator do
      assert_file "jsconfig.json"
    end
  end
end

class ShadcnDisabledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_shadcn = false
    use_typescript = true
    js_ext = "ts"
    use_starter_kit = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    post_install_commands = []
    eslint_ignores = []
    <%= include "shadcn" %>
  CODE

  def test_skips_when_disabled
    run_generator do
      refute_file "components.json"
      refute_file "app/javascript/lib/utils.ts"
    end
  end
end
