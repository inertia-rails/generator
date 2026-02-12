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

class E2eTest < Minitest::Test
  COMPILED_TEMPLATE = E2eHelpers.compiled_template_path

  # Test configurations: [name, env_vars]
  # 4 configs covering the key code paths (~2 min total).
  # Extended configs for pre-release matrix runs are in matrix_test.rb.
  CONFIGS = {
    # ─── Starter Kit (all options forced on) ─────────────────────────
    "react_starter_kit" => {
      "INERTIA_FRAMEWORK" => "react",
      "INERTIA_STARTER_KIT" => "1",
      "INERTIA_TYPELIZER" => "1"
    },
    "svelte_starter_kit" => {
      "INERTIA_FRAMEWORK" => "svelte",
      "INERTIA_STARTER_KIT" => "1",
      "INERTIA_TYPELIZER" => "1"
    },
    # ─── Foundation (individual options) ─────────────────────────────
    "vue_minimal" => {
      "INERTIA_FRAMEWORK" => "vue",
      "INERTIA_STARTER_KIT" => "0",
      "INERTIA_TS" => "0",
      "INERTIA_TAILWIND" => "0",
      "INERTIA_SHADCN" => "0",
      "INERTIA_ESLINT" => "0",
      "INERTIA_SSR" => "0"
    },
    "react_ts_tailwind_shadcn" => {
      "INERTIA_FRAMEWORK" => "react",
      "INERTIA_STARTER_KIT" => "0",
      "INERTIA_TS" => "1",
      "INERTIA_TAILWIND" => "1",
      "INERTIA_SHADCN" => "1",
      "INERTIA_ESLINT" => "0",
      "INERTIA_SSR" => "0"
    }
  }.freeze

  def setup
    E2eHelpers.compile_template(COMPILED_TEMPLATE) unless File.exist?(COMPILED_TEMPLATE)
  end

  CONFIGS.each do |name, env|
    define_method(:"test_#{name}") do
      run_e2e(name, env)
    end
  end

  private

  def run_in_app(app_path, cmd)
    stdout, stderr, status = ::Bundler.with_original_env do
      Open3.capture3(cmd, chdir: app_path)
    end
    [stdout, stderr, status]
  end

  def run_e2e(name, env)
    Dir.mktmpdir("inertia_e2e_") do |tmpdir|
      app_name = "testapp_#{name}"
      app_path = File.join(tmpdir, app_name)

      is_starter_kit = env["INERTIA_STARTER_KIT"] == "1"

      flags = is_starter_kit ? E2eHelpers::STARTER_KIT_FLAGS : E2eHelpers::FOUNDATION_FLAGS
      cmd = ["rails", "new", app_name, "-m", COMPILED_TEMPLATE, *flags]

      template_env = E2eHelpers::COMMON_ENV.merge(env).merge(
        "BUNDLE_IGNORE_MESSAGES" => "1"
      )

      stdout, stderr, status = ::Bundler.with_original_env do
        Open3.capture3(template_env, *cmd, chdir: tmpdir)
      end

      output = "#{stdout}\n#{stderr}"
      assert status.success?, "rails new failed for #{name} (exit #{status.exitstatus}):\n#{tail(output)}"

      assert_core_files(app_path)
      assert_framework_deps(app_path, env["INERTIA_FRAMEWORK"])

      if is_starter_kit
        assert_starter_kit_files(app_path, env)
      else
        assert_foundation_files(app_path)
      end

      assert output.include?("Inertia Rails installed successfully"), "Missing success message in output"

      assert_builds_pass(app_path, name, env)
    end
  end

  def assert_core_files(app_path)
    assert File.exist?(File.join(app_path, "Gemfile")), "Missing Gemfile"
    assert File.exist?(File.join(app_path, "package.json")), "Missing package.json"
    assert File.exist?(File.join(app_path, "config/initializers/inertia_rails.rb")), "Missing inertia initializer"
    assert File.exist?(File.join(app_path, "Procfile.dev")), "Missing Procfile.dev"
    assert File.exist?(File.join(app_path, "bin/dev")), "Missing bin/dev"

    gemfile = File.read(File.join(app_path, "Gemfile"))
    assert gemfile.include?("inertia_rails"), "Gemfile missing inertia_rails"
    assert gemfile.include?("rails_vite"), "Gemfile missing rails_vite"

    vite_configs = Dir.glob(File.join(app_path, "vite.config.*"))
    assert vite_configs.any?, "Missing vite.config.*"

    assert File.exist?(File.join(app_path, "app/controllers/inertia_controller.rb")), "Missing InertiaController"

    app_layout = File.read(File.join(app_path, "app/views/layouts/application.html.erb"))
    assert app_layout.include?("vite_tags"), "Layout missing vite_tags"
  end

  def assert_framework_deps(app_path, framework)
    pkg_raw = File.read(File.join(app_path, "package.json"))
    case framework
    when "react" then assert pkg_raw.include?("@inertiajs/react"), "package.json missing @inertiajs/react"
    when "vue" then assert pkg_raw.include?("@inertiajs/vue3"), "package.json missing @inertiajs/vue3"
    when "svelte" then assert pkg_raw.include?("@inertiajs/svelte"), "package.json missing @inertiajs/svelte"
    end
  end

  def assert_starter_kit_files(app_path, env)
    gemfile = File.read(File.join(app_path, "Gemfile"))

    assert File.exist?(File.join(app_path, "app/models/user.rb")), "Missing User model"
    assert File.exist?(File.join(app_path, "app/models/session.rb")), "Missing Session model"
    assert File.exist?(File.join(app_path, "app/controllers/sessions_controller.rb")), "Missing SessionsController"
    assert File.exist?(File.join(app_path, "app/controllers/dashboard_controller.rb")), "Missing DashboardController"
    assert File.exist?(File.join(app_path, "app/controllers/settings/profiles_controller.rb")), "Missing Settings::ProfilesController"
    assert File.exist?(File.join(app_path, "app/mailers/user_mailer.rb")), "Missing UserMailer"
    assert gemfile.include?("bcrypt"), "Gemfile missing bcrypt"

    assert Dir.glob(File.join(app_path, "app/javascript/pages/sessions/new.*")).any?, "Missing login page"
    assert Dir.glob(File.join(app_path, "app/javascript/pages/users/new.*")).any?, "Missing registration page"
    assert Dir.glob(File.join(app_path, "app/javascript/pages/dashboard/index.*")).any?, "Missing dashboard page"
    assert Dir.glob(File.join(app_path, "app/javascript/pages/settings/profiles/show.*")).any?, "Missing settings profile page"

    app_layouts = Dir.glob(File.join(app_path, "app/javascript/layouts/{app-layout,AppLayout}.*"))
    assert app_layouts.any?, "Missing app layout"
    auth_layouts = Dir.glob(File.join(app_path, "app/javascript/layouts/{auth-layout,AuthLayout}.*"))
    assert auth_layouts.any?, "Missing auth layout"

    assert Dir.glob(File.join(app_path, "app/javascript/components/ui/sidebar*")).any?, "Missing shadcn sidebar"

    # Test files (fixtures shared, framework-specific tests)
    assert File.exist?(File.join(app_path, "test/fixtures/users.yml")), "Missing users fixture"

    test_fw = env.fetch("INERTIA_TEST_FRAMEWORK", "minitest")
    if test_fw == "rspec"
      assert gemfile.include?("rspec-rails"), "Gemfile missing rspec-rails"
      assert File.exist?(File.join(app_path, ".rspec")), "Missing .rspec"
      assert File.exist?(File.join(app_path, "spec/rails_helper.rb")), "Missing rails_helper.rb"
      assert File.exist?(File.join(app_path, "spec/support/authentication_helpers.rb")), "Missing authentication helpers"
      assert File.exist?(File.join(app_path, "spec/requests/sessions_spec.rb")), "Missing sessions spec"
      assert File.exist?(File.join(app_path, "spec/mailers/user_mailer_spec.rb")), "Missing user mailer spec"
    else
      assert File.exist?(File.join(app_path, "test/test_helpers/session_test_helper.rb")), "Missing session test helper"
      assert File.exist?(File.join(app_path, "test/controllers/sessions_controller_test.rb")), "Missing sessions controller test"
      assert File.exist?(File.join(app_path, "test/mailers/user_mailer_test.rb")), "Missing user mailer test"
    end
  end

  def assert_foundation_files(app_path)
    assert File.exist?(File.join(app_path, "app/controllers/home_controller.rb")), "Missing HomeController for foundation"
    assert Dir.glob(File.join(app_path, "app/javascript/pages/home/index.*")).any?, "Missing example home page"
  end

  def assert_builds_pass(app_path, name, env)
    is_starter_kit = env["INERTIA_STARTER_KIT"] == "1"

    # Rails boot check
    out, err, st = run_in_app(app_path, "bin/rails runner 'puts :ok'")
    assert st.success?, "Rails boot failed for #{name}:\n#{tail("#{out}\n#{err}")}"

    # Vite client build
    out, err, st = run_in_app(app_path, "npx vite build")
    assert st.success?, "vite build failed for #{name}:\n#{tail("#{out}\n#{err}")}"

    # Vite SSR build (starter kit forces SSR on)
    if is_starter_kit || env["INERTIA_SSR"] == "1"
      out, err, st = run_in_app(app_path, "npx vite build --ssr")
      assert st.success?, "vite build --ssr failed for #{name}:\n#{tail("#{out}\n#{err}")}"
    end

    # Run npm scripts only if they exist in package.json
    pkg = JSON.parse(File.read(File.join(app_path, "package.json")))
    scripts = pkg.fetch("scripts", {})

    if scripts.key?("check")
      out, err, st = run_in_app(app_path, "npm run check")
      assert st.success?, "npm run check failed for #{name}:\n#{tail("#{out}\n#{err}")}"
    end

    if scripts.key?("lint")
      out, err, st = run_in_app(app_path, "npm run lint")
      assert st.success?, "npm run lint failed for #{name}:\n#{tail("#{out}\n#{err}")}"
    end

    if scripts.key?("format")
      out, err, st = run_in_app(app_path, "npm run format")
      assert st.success?, "npm run format failed for #{name}:\n#{tail("#{out}\n#{err}")}"
    end

    # Run starter kit tests (minitest or rspec)
    if is_starter_kit
      test_fw = env.fetch("INERTIA_TEST_FRAMEWORK", "minitest")
      test_cmd = (test_fw == "rspec") ? "bundle exec rspec" : "bin/rails test"
      out, err, st = run_in_app(app_path, test_cmd)
      assert st.success?, "#{test_cmd} failed for #{name}:\n#{tail("#{out}\n#{err}")}"
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
