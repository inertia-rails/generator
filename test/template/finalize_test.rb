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

# Plugins a React + Tailwind install accumulates before finalize runs
# (the Tailwind partial runs first, so its plugin is registered first)
EXISTING_VITE_PLUGINS = <<~CODE
  vite_plugins = [
    { import: "import tailwindcss from '@tailwindcss/vite'", call: "tailwindcss()" },
    { import: "import react, { reactCompilerPreset } from '@vitejs/plugin-react'", call: "react()" },
    { import: "import babel from '@rolldown/plugin-babel'", call: "babel({ presets: [reactCompilerPreset()] })" }
  ]
CODE

class FinalizeExistingViteConfigTest < GeneratorTestCase
  template <<~CODE
    #{FINALIZE_PREAMBLE}
    #{EXISTING_VITE_PLUGINS}
    #{NOOP_ADD_GEM}
    self.class.define_method(:after_bundle) { |&block| block&.call }
    file "vite.config.ts", <<~JS
      import { defineConfig } from 'vite'
      import rails from 'rails-vite-plugin'

      export default defineConfig({
        plugins: [
          rails(),
        ],
      })
    JS
    <%= include "finalize" %>
  CODE

  def test_appends_plugins_after_existing_ones_in_order
    run_generator do
      config = File.read(File.join(destination, "vite.config.ts"))
      assert_includes config, <<~JS
        export default defineConfig({
          plugins: [
            rails(),
            react(),
            babel({ presets: [reactCompilerPreset()] }),
            tailwindcss(),
            inertia({ ssr: 'app/javascript/entrypoints/inertia.jsx' }),
          ],
        })
      JS
    end
  end

  def test_adds_imports_in_order
    run_generator do
      config = File.read(File.join(destination, "vite.config.ts"))
      assert config.start_with?(<<~JS), "imports should be prepended in plugin order:\n\#{config}"
        import react, { reactCompilerPreset } from '@vitejs/plugin-react'
        import babel from '@rolldown/plugin-babel'
        import tailwindcss from '@tailwindcss/vite'
        import inertia from '@inertiajs/vite'
        import { defineConfig } from 'vite'
      JS
    end
  end

  def test_keeps_the_existing_config_file
    run_generator do
      refute_file "vite.config.js"
    end
  end
end

class FinalizeExistingViteConfigRerunTest < GeneratorTestCase
  template <<~CODE
    #{FINALIZE_PREAMBLE}
    #{EXISTING_VITE_PLUGINS}
    #{NOOP_ADD_GEM}
    self.class.define_method(:after_bundle) { |&block| block&.call }
    file "vite.config.ts", <<~JS
      import inertia from '@inertiajs/vite'
      import react, { reactCompilerPreset } from '@vitejs/plugin-react'
      import { defineConfig } from 'vite'
      import rails from 'rails-vite-plugin'

      export default defineConfig({
        plugins: [
          rails(),
          react(),
          inertia()
        ],
      })
    JS
    <%= include "finalize" %>
  CODE

  def test_adds_only_what_is_missing
    run_generator do
      config = File.read(File.join(destination, "vite.config.ts"))
      assert_equal 1, config.scan("react()").size, "react() should not be added twice"
      assert_equal 1, config.scan("import inertia").size, "inertia should not be imported twice"
      assert_equal 1, config.scan("inertia(").size, "inertia() should not be added twice"
      assert_includes config, "    inertia(),\n    babel({ presets: [reactCompilerPreset()] }),\n    tailwindcss(),\n  ],"
    end
  end
end

class FinalizeExistingViteConfigWithFrameworkTest < GeneratorTestCase
  template <<~CODE
    #{FINALIZE_PREAMBLE}
    #{EXISTING_VITE_PLUGINS}
    #{NOOP_ADD_GEM}
    self.class.define_method(:after_bundle) { |&block| block&.call }
    file "vite.config.ts", <<~JS
      import { defineConfig } from 'vite'
      import react from '@vitejs/plugin-react'
      import rails from 'rails-vite-plugin'
      import { viteStaticCopy } from 'vite-plugin-static-copy'

      export default defineConfig({
        plugins: [
          react({ jsxImportSource: '@emotion/react' }),
          viteStaticCopy({
            targets: [
              { src: 'a', dest: 'b' },
            ],
          }),
          rails(),
        ],
      })
    JS
    <%= include "finalize" %>
  CODE

  def test_keeps_a_framework_plugin_that_has_options
    run_generator do
      config = File.read(File.join(destination, "vite.config.ts"))
      assert_equal 1, config.scan("react(").size, "react() should not be added next to react({ ... })"
      assert_equal 1, config.scan("import react").size, "react should not be imported twice"
    end
  end

  def test_imports_the_compiler_preset_on_its_own
    run_generator do
      assert_file_contains "vite.config.ts", "import { reactCompilerPreset } from '@vitejs/plugin-react'"
    end
  end

  def test_appends_to_the_plugins_array_not_a_nested_one
    run_generator do
      config = File.read(File.join(destination, "vite.config.ts"))
      assert_includes config, "        { src: 'a', dest: 'b' },\n      ],\n    }),\n    rails(),\n", "nested array should be untouched"
      assert_includes config, "    rails(),\n    babel({ presets: [reactCompilerPreset()] }),\n    tailwindcss(),\n" \
        "    inertia({ ssr: 'app/javascript/entrypoints/inertia.jsx' }),\n  ],\n})"
    end
  end
end

class FinalizeExistingViteConfigSingleLineTest < GeneratorTestCase
  template <<~CODE
    #{FINALIZE_PREAMBLE}
    #{EXISTING_VITE_PLUGINS}
    #{NOOP_ADD_GEM}
    self.class.define_method(:after_bundle) { |&block| block&.call }
    file "vite.config.ts", "export default { plugins: [rails()] }\n"
    <%= include "finalize" %>
  CODE

  def test_asks_for_a_manual_edit_instead_of_guessing
    run_generator do |output|
      assert_line_printed output, "Add this plugin manually: react()"
      assert_file_contains "vite.config.ts", "plugins: [rails()]"
    end
  end
end
