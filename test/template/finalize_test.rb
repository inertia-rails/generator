# frozen_string_literal: true

require_relative "../test_helper"

# Extends DEPLOY_PREAMBLE with finalize-specific variables
FINALIZE_PREAMBLE = <<~CODE
  #{GeneratorTestCase::DEPLOY_PREAMBLE}
  npm_packages = []
  npm_dev_packages = []
  gems_to_add = []
  vite_plugins = []
  post_install_commands = []
  vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"
  bundle_run = ->(*cmds) {}
  importmap_detected = false
CODE

class FinalizeGemInstallTest < GeneratorTestCase
  template <<~CODE
    #{FINALIZE_PREAMBLE}
    npm_packages = ["react"]
    npm_dev_packages = ["typescript"]
    gems_to_add = ["test-gem", {name: "grouped-gem", group: :development}, {name: "multi-group-gem", group: %i[development test]}]
    #{ADD_GEM}
    self.class.define_method(:after_bundle) { |&block| block&.call }
    <%= include "finalize" %>
  CODE

  def test_finalize_prints_success
    run_generator do |output|
      assert_line_printed output, "Inertia Rails installed successfully"
    end
  end

  def test_finalize_creates_procfile
    run_generator do
      assert_file "Procfile.dev"
      assert_file_contains "Procfile.dev", "npx vite"
      assert_file_contains "Procfile.dev", "bin/rails s"
    end
  end

  def test_finalize_creates_bin_dev
    run_generator do
      assert_file "bin/dev"
    end
  end

  def test_finalize_adds_gems_to_gemfile
    run_generator do
      assert_file_contains "Gemfile", 'gem "test-gem"'
    end
  end

  def test_finalize_adds_grouped_gem
    run_generator do
      assert_file_contains "Gemfile", 'gem "grouped-gem", group: [:development]'
    end
  end

  def test_finalize_adds_multi_group_gem
    run_generator do
      assert_file_contains "Gemfile", 'gem "multi-group-gem", group: [:development, :test]'
    end
  end
end

class FinalizeViteConfigTest < GeneratorTestCase
  template <<~CODE
    #{FINALIZE_PREAMBLE}
    #{NOOP_ADD_GEM}
    self.class.define_method(:after_bundle) { |&block| block&.call }
    <%= include "finalize" %>
  CODE

  def test_vite_config_always_ssr_ready
    run_generator do
      assert_file "vite.config.js"
      assert_file_contains "vite.config.js", "defineConfig(({ command })"
      assert_file_contains "vite.config.js", "noExternal"
      assert_file_contains "vite.config.js", "ssr: 'app/javascript/entrypoints/inertia.jsx'"
    end
  end

  def test_mentions_ssr_ready_when_disabled
    run_generator do |output|
      assert_line_printed output, "SSR-ready"
    end
  end
end

class FinalizeViteConfigSsrTest < GeneratorTestCase
  template <<~CODE
    #{FINALIZE_PREAMBLE}
    use_ssr = true
    #{NOOP_ADD_GEM}
    self.class.define_method(:after_bundle) { |&block| block&.call }
    <%= include "finalize" %>
  CODE

  def test_vite_config_includes_ssr_config
    run_generator do
      assert_file_contains "vite.config.js", "noExternal"
      assert_file_contains "vite.config.js", "command === 'build'"
    end
  end

  def test_mentions_ssr_build_when_enabled
    run_generator do |output|
      assert_line_printed output, "vite build --ssr"
    end
  end
end

class FinalizeStarterKitMessageTest < GeneratorTestCase
  template <<~CODE
    #{FINALIZE_PREAMBLE}
    use_starter_kit = true
    #{NOOP_ADD_GEM}
    self.class.define_method(:after_bundle) { |&block| block&.call }
    <%= include "finalize" %>
  CODE

  def test_mentions_starter_kit_when_enabled
    run_generator do |output|
      assert_line_printed output, "Starter Kit with authentication is ready"
    end
  end
end

%w[npm yarn pnpm bun].each do |pm|
  klass = Class.new(GeneratorTestCase) do
    template <<~CODE
      #{FINALIZE_PREAMBLE}
      package_manager = "#{pm}"
      npm_packages = ["react"]
      #{GeneratorTestCase::NOOP_ADD_GEM}
      self.class.define_method(:after_bundle) { |&block| block&.call }
      <%= include "finalize" %>
    CODE

    define_method("test_finalize_with_#{pm}") do
      run_generator do |output|
        assert_line_printed output, "Inertia Rails installed successfully"
      end
    end
  end

  Object.const_set("FinalizePackageManager#{pm.capitalize}Test", klass)
end
