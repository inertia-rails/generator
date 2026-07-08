# frozen_string_literal: true

require "minitest/autorun"
require "minitest/reporters"
require "open3"
require "fileutils"
require "tmpdir"
require "json"
require "bundler"

require_relative "support/e2e_helpers"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Existing-app installs: apply the compiled template to pre-existing Rails apps
# via `bin/rails app:template` — the same code path the future
# `inertia_rails:install` shim uses (Rails::Generators::AppGenerator.apply_rails_template).
#
# Tier 1 asserts successful installs (plain apps, auto-detection).
# Tier 2 asserts clean refusals (conflicting setups, dirty trees) — a hard
# exit with guidance beats a broken half-install.
class ExistingAppTest < Minitest::Test
  COMPILED_TEMPLATE = File.join(Dir.tmpdir, "inertia_existing_template.rb")

  FULL_ENV = {
    "INERTIA_FRAMEWORK" => "react",
    "INERTIA_TS" => "1",
    "INERTIA_TAILWIND" => "1",
    "INERTIA_SHADCN" => "0",
    "INERTIA_ESLINT" => "0",
    "INERTIA_SSR" => "0",
    "INERTIA_TYPELIZER" => "0",
    "INERTIA_ALBA" => "0",
    "INERTIA_SYSTEM_TESTS" => "0",
    "INERTIA_TEST_FRAMEWORK" => "minitest",
    "BUNDLE_IGNORE_MESSAGES" => "1"
  }.freeze

  ADAPTER_PACKAGES = {
    "react" => "@inertiajs/react",
    "vue" => "@inertiajs/vue3",
    "svelte" => "@inertiajs/svelte"
  }.freeze

  def setup
    E2eHelpers.compile_template(COMPILED_TEMPLATE) unless File.exist?(COMPILED_TEMPLATE)
  end

  # ─── Tier 1: successful installs ────────────────────────────────────

  def test_plain_app_react_ts_tailwind
    with_base_app do |app|
      out, status = apply_template(app, FULL_ENV)

      assert status.success?, "app:template failed:\n#{tail(out)}"
      assert_includes out, "Detected: existing Rails app"
      assert_includes out, "Inertia Rails installed successfully"
      # Plain Rails apps ship importmap; we warn instead of removing it
      assert_includes out, "importmap-rails is still installed"
      assert_installed(app, framework: "react")
      assert_builds(app)
    end
  end

  def test_plain_app_vue_js_minimal
    env = FULL_ENV.merge(
      "INERTIA_FRAMEWORK" => "vue",
      "INERTIA_TS" => "0",
      "INERTIA_TAILWIND" => "0"
    )

    with_base_app do |app|
      out, status = apply_template(app, env)

      assert status.success?, "app:template failed:\n#{tail(out)}"
      assert_includes out, "Inertia Rails installed successfully"
      assert_installed(app, framework: "vue")
      refute File.exist?(File.join(app, "tsconfig.json")), "tsconfig.json created despite INERTIA_TS=0"
      assert_builds(app)
    end
  end

  def test_auto_detects_existing_frontend_setup
    with_base_app do |app|
      File.write(File.join(app, "package.json"), JSON.pretty_generate(
        name: "base_app",
        private: true,
        type: "module",
        dependencies: {"svelte" => "^5.0.0"},
        devDependencies: {"tailwindcss" => "^4.0.0"}
      ))
      File.write(File.join(app, "tsconfig.json"), "{}\n")
      commit(app)

      env = FULL_ENV.except("INERTIA_FRAMEWORK", "INERTIA_TS", "INERTIA_TAILWIND")
      out, status = apply_template(app, env)

      assert status.success?, "app:template failed:\n#{tail(out)}"
      assert_includes out, "Framework: svelte (auto-detected)"
      assert_includes out, "TypeScript: yes (auto-detected)"
      assert_includes out, "Tailwind CSS: yes (auto-detected)"
      assert_installed(app, framework: "svelte")
      assert_builds(app)
    end
  end

  # ─── Tier 2: clean refusals ─────────────────────────────────────────

  def test_refuses_jsbundling_app
    with_base_app do |app|
      add_fake_gem(app, "jsbundling-rails")
      commit(app)

      out, status = apply_template(app, FULL_ENV)

      refute status.success?, "expected refusal, got success:\n#{tail(out)}"
      assert_includes out, "jsbundling-rails and/or cssbundling-rails detected"
    end
  end

  def test_refuses_vite_rails_app
    with_base_app do |app|
      add_fake_gem(app, "vite_rails")
      commit(app)

      out, status = apply_template(app, FULL_ENV)

      refute status.success?, "expected refusal, got success:\n#{tail(out)}"
      assert_includes out, "vite_rails/vite_ruby detected"
      assert_includes out, "Migrate to rails_vite"
    end
  end

  def test_refuses_api_only_app
    with_base_app(flags: ["--api"]) do |app|
      out, status = apply_template(app, FULL_ENV)

      refute status.success?, "expected refusal, got success:\n#{tail(out)}"
      assert_includes out, "Inertia requires a full Rails app"
    end
  end

  def test_refuses_dirty_git_tree
    with_base_app do |app|
      File.write(File.join(app, "junk.txt"), "uncommitted")

      out, status = apply_template(app, FULL_ENV)

      refute status.success?, "expected refusal, got success:\n#{tail(out)}"
      assert_includes out, "Uncommitted changes detected"

      # Escape hatch proceeds past the guard
      out, _status = apply_template(app, FULL_ENV.merge("INERTIA_ALLOW_DIRTY" => "1"))
      refute_includes out, "Uncommitted changes detected"
    end
  end

  private

  # Pin the Rails that generates base apps (exact gem version, e.g. "7.2.3.1").
  # CI lanes install a single railties instead; this is for local runs where
  # several versions coexist.
  RAILS_PIN = ENV["EXISTING_APP_RAILS"]

  def rails_cmd
    RAILS_PIN ? ["rails", "_#{RAILS_PIN}_"] : ["rails"]
  end

  # --skip-kamal only exists on Rails >= 8.0; older rails new dies on unknown switches
  def base_flags
    @base_flags ||= begin
      help, = ::Bundler.with_original_env { Open3.capture2e(*rails_cmd, "new", "--help") }
      help.include?("--skip-kamal") ? ["--skip-kamal"] : []
    end
  end

  def with_base_app(flags: [])
    Dir.mktmpdir("inertia_existing_") do |tmpdir|
      app = File.join(tmpdir, "base_app")
      cmd = [*rails_cmd, "new", "base_app", *base_flags, *flags]

      _out, err, status = ::Bundler.with_original_env do
        Open3.capture3(*cmd, chdir: tmpdir)
      end
      raise "rails new failed:\n#{tail(err)}" unless status.success?

      commit(app)
      yield app
    end
  end

  # Add a gem to the app's Gemfile backed by a local fake so the app still
  # boots without the real gem installed (bundler resolves path gems offline)
  def add_fake_gem(app, name)
    fake = File.join(app, "vendor", name)
    FileUtils.mkdir_p(fake)
    File.write(File.join(fake, "#{name}.gemspec"), <<~SPEC)
      Gem::Specification.new do |s|
        s.name = #{name.inspect}
        s.version = "1.0.0"
        s.summary = "test double"
        s.authors = ["test"]
      end
    SPEC
    File.write(File.join(app, "Gemfile"), "gem #{name.inspect}, path: #{File.join("vendor", name).inspect}, require: false\n", mode: "a")
  end

  def commit(app)
    Open3.capture3("git", "add", "-A", chdir: app)
    Open3.capture3(
      "git", "-c", "user.email=ci@example.com", "-c", "user.name=CI",
      "-c", "commit.gpgsign=false", "commit", "-qm", "base",
      chdir: app
    )
  end

  def apply_template(app, env)
    stdout, stderr, status = ::Bundler.with_original_env do
      Open3.capture3(env, "bin/rails", "app:template", "LOCATION=#{COMPILED_TEMPLATE}", chdir: app)
    end
    ["#{stdout}\n#{stderr}", status]
  end

  def assert_installed(app, framework:)
    assert File.exist?(File.join(app, "config/initializers/inertia_rails.rb")), "Missing inertia initializer"
    assert File.exist?(File.join(app, "bin/dev")), "Missing bin/dev"

    gemfile = File.read(File.join(app, "Gemfile"))
    assert_includes gemfile, "inertia_rails"
    assert_includes gemfile, "rails_vite"

    pkg = File.read(File.join(app, "package.json"))
    assert_includes pkg, ADAPTER_PACKAGES.fetch(framework)
  end

  def assert_builds(app)
    out, err, status = run_in_app(app, "bin/rails runner 'puts :ok'")
    assert status.success?, "Rails boot failed:\n#{tail("#{out}\n#{err}")}"

    out, err, status = run_in_app(app, "npx vite build")
    assert status.success?, "vite build failed:\n#{tail("#{out}\n#{err}")}"
  end

  def run_in_app(app, cmd)
    ::Bundler.with_original_env do
      Open3.capture3(cmd, chdir: app)
    end
  end

  def tail(output, lines: 80)
    output_lines = output.lines
    if output_lines.size > lines
      "...(truncated #{output_lines.size - lines} lines)...\n#{output_lines.last(lines).join}"
    else
      output
    end
  end
end
