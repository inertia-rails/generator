# frozen_string_literal: true

require_relative "../test_helper"

class EslintReactTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_eslint = true
    use_typescript = true
    use_tailwind = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    eslint_ignores = []
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "eslint" %>
  CODE

  def test_creates_eslint_config
    run_generator do |output|
      assert_file "eslint.config.js"
      assert_line_printed output, "Setting up ESLint + Prettier"
    end
  end

  def test_creates_prettierrc
    run_generator do
      assert_file ".prettierrc"
      refute_file_contains ".prettierrc", "prettier-plugin-tailwindcss"
    end
  end

  def test_adds_lint_scripts
    run_generator do
      pkg = JSON.parse(File.read(File.join(destination, "package.json")))
      assert_includes pkg.dig("scripts", "lint"), "--report-unused-disable-directives --max-warnings 0"
      assert_includes pkg.dig("scripts", "lint"), "'*.{js,mjs,cjs,ts}'"
      assert_includes pkg.dig("scripts", "lint:fix"), "--fix"
      assert_includes pkg.dig("scripts", "format"), "--check"
      assert_includes pkg.dig("scripts", "format:fix"), "--write"
    end
  end

  def test_creates_prettierignore
    run_generator do
      # exact match: no trailing blank line when eslint_ignores is empty
      assert_equal "build\ncoverage\n", File.read(File.join(destination, ".prettierignore"))
    end
  end
end

class EslintPrettierIgnoreTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_eslint = true
    use_typescript = true
    use_tailwind = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    eslint_ignores = ["components/ui/**", "routes/**", "types/serializers/**"]
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "eslint" %>
  CODE

  def test_prettierignore_covers_generated_dirs
    run_generator do
      assert_file_contains ".prettierignore", "app/javascript/components/ui"
      assert_file_contains ".prettierignore", "app/javascript/routes"
      assert_file_contains ".prettierignore", "app/javascript/types/serializers"
      refute_file_contains ".prettierignore", "/**"
    end
  end
end

class EslintVueTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "vue"
    use_eslint = true
    use_typescript = true
    use_tailwind = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    eslint_ignores = []
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "eslint" %>
  CODE

  def test_creates_eslint_config
    run_generator do
      assert_file "eslint.config.js"
    end
  end
end

class EslintSvelteTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "svelte"
    use_eslint = true
    use_typescript = true
    use_tailwind = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    eslint_ignores = []
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "eslint" %>
  CODE

  def test_creates_eslint_config
    run_generator do
      assert_file "eslint.config.js"
    end
  end
end

class EslintWithTailwindTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_eslint = true
    use_typescript = true
    use_tailwind = true
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    eslint_ignores = []
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "eslint" %>
  CODE

  def test_uses_tailwind_prettierrc
    run_generator do
      assert_file ".prettierrc"
      assert_file_contains ".prettierrc", "prettier-plugin-tailwindcss"
    end
  end
end

class EslintDisabledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_eslint = false
    use_typescript = true
    use_tailwind = false
    js_destination_path = "app/javascript"
    npm_dev_packages = []
    eslint_ignores = []
    #{UPDATE_PACKAGE_JSON}
    #{STUB_PACKAGE_JSON}
    <%= include "eslint" %>
  CODE

  def test_skips_when_disabled
    run_generator do
      refute_file "eslint.config.js"
      refute_file ".prettierrc"
    end
  end
end
