# frozen_string_literal: true

require_relative "../test_helper"

class DeployDockerfileTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    file "Dockerfile", "placeholder"
    file ".ruby-version", "3.3.0"
    <%= include "deploy" %>
  CODE

  def test_generates_complete_dockerfile
    run_generator do
      assert_file_contains "Dockerfile", "node-build"
      assert_file_contains "Dockerfile", "node-gyp"
      assert_file_contains "Dockerfile", "npm ci"
      assert_file_contains "Dockerfile", "COPY package.json package-lock.json"
    end
  end

  def test_cleans_node_modules_after_precompile
    run_generator do
      content = File.read(File.join(destination, "Dockerfile"))
      assert content.include?("rm -rf node_modules"), "Should clean node_modules after precompile"
      precompile_pos = content.index("assets:precompile")
      cleanup_pos = content.index("rm -rf node_modules")
      assert precompile_pos < cleanup_pos, "node_modules cleanup should come after precompile"
    end
  end

  def test_uses_ruby_version_from_file
    run_generator do
      assert_file_contains "Dockerfile", "ARG RUBY_VERSION=3.3.0"
    end
  end

  def test_detects_sqlite3_by_default
    run_generator do
      assert_file_contains "Dockerfile", "sqlite3"
    end
  end
end

class DeployDockerfilePostgresTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    db_adapter = "postgresql"
    file "Dockerfile", "placeholder"
    append_to_file "Gemfile", "gem \\"pg\\"\\n"
    <%= include "deploy" %>
  CODE

  def test_uses_postgresql_packages
    run_generator do
      assert_file_contains "Dockerfile", "postgresql-client"
      assert_file_contains "Dockerfile", "libpq-dev"
    end
  end
end

class DeployDockerfileTrilogyTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    db_adapter = "trilogy"
    file "Dockerfile", "placeholder"
    append_to_file "Gemfile", "gem \\"trilogy\\"\\n"
    <%= include "deploy" %>
  CODE

  def test_trilogy_keeps_mysql_client_in_base_for_dbconsole
    run_generator do
      assert_file_contains "Dockerfile", "default-mysql-client"
    end
  end

  def test_trilogy_skips_libmysqlclient_dev_in_build
    run_generator do
      refute_file_contains "Dockerfile", "default-libmysqlclient-dev"
    end
  end
end

class DeployDockerfileBunTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    package_manager = "bun"
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_uses_bun_instead_of_node
    run_generator do
      content = File.read(File.join(destination, "Dockerfile"))
      assert content.include?("bun install"), "Should use bun install"
      assert content.include?("bun.sh/install"), "Should install Bun runtime"
      refute content.include?("node-build"), "Should not install Node.js"
    end
  end
end

class DeployDockerfileYarn1Test < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    package_manager = "yarn"
    yarn_version = "1.22.22"
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_yarn_1_installs_via_npm_global_with_frozen_lockfile
    run_generator do
      assert_file_contains "Dockerfile", "ARG YARN_VERSION=1.22.22"
      assert_file_contains "Dockerfile", "npm install -g yarn@$YARN_VERSION"
      assert_file_contains "Dockerfile", "yarn install --frozen-lockfile"
      refute_file_contains "Dockerfile", "corepack enable && yarn set version"
    end
  end
end

class DeployDockerfileYarnBerryTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    package_manager = "yarn"
    yarn_version = "4.5.0"
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_yarn_berry_installs_via_corepack_with_immutable
    run_generator do
      assert_file_contains "Dockerfile", "ARG YARN_VERSION=4.5.0"
      assert_file_contains "Dockerfile", "corepack enable && yarn set version $YARN_VERSION"
      assert_file_contains "Dockerfile", "yarn install --immutable"
      refute_file_contains "Dockerfile", "npm install -g yarn@"
      refute_file_contains "Dockerfile", "yarn install --frozen-lockfile"
    end
  end
end

class DeployDockerfileYarnLatestTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    package_manager = "yarn"
    yarn_version = "latest"
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_latest_uses_corepack_path
    run_generator do
      assert_file_contains "Dockerfile", "corepack enable && yarn set version"
      assert_file_contains "Dockerfile", "yarn install --immutable"
    end
  end
end

class DeployDockerfilePnpmVersionTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    package_manager = "pnpm"
    pnpm_version = "10.28.2"
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_pins_pnpm_version_not_latest
    run_generator do
      assert_file_contains "Dockerfile", "corepack prepare pnpm@10.28.2 --activate"
      refute_file_contains "Dockerfile", "pnpm@latest"
    end
  end
end

class DeployDockerfileSsrTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    use_ssr = true
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_arg_ssr_enabled_defaults_true
    run_generator do
      assert_file_contains "Dockerfile", "ARG SSR_ENABLED=true"
    end
  end

  def test_node_runtime_installed_in_build_stage_not_base
    run_generator do
      content = File.read(File.join(destination, "Dockerfile"))
      base_section = content[0...content.index("FROM base AS build")]
      refute base_section.include?("node-build"),
        "Node.js should not be installed in base stage anymore"
      build_section = content[content.index("FROM base AS build")...content.index("FROM base AS branch-ssr-true")]
      assert build_section.include?("node-build"),
        "Node.js should be installed in build stage"
    end
  end

  def test_branch_ssr_true_copies_node_runtime
    run_generator do
      assert_file_contains "Dockerfile", "FROM base AS branch-ssr-true"
      assert_file_contains "Dockerfile", "COPY --from=build /usr/local/node /usr/local/node"
      assert_file_contains "Dockerfile", "ENV PATH=/usr/local/node/bin:$PATH"
    end
  end

  def test_final_stage_picks_branch_via_arg
    run_generator do
      assert_file_contains "Dockerfile", "FROM branch-ssr-${SSR_ENABLED} AS final"
    end
  end

  def test_precompile_and_ssr_are_separate_runs
    run_generator do
      content = File.read(File.join(destination, "Dockerfile"))
      assert content.include?("RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile\n"),
        "assets:precompile should be its own RUN (no trailing && for SSR)"
      assert content.include?('if [ "$SSR_ENABLED" = "true" ]; then npx vite build --ssr'),
        "SSR build should be shell-conditional on SSR_ENABLED"
      assert content.include?("rm -rf node_modules"),
        "node_modules cleanup should be folded into SSR RUN"
    end
  end

  def test_final_stage_preserves_chown_on_copy
    run_generator do
      assert_file_contains "Dockerfile", 'COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"'
      assert_file_contains "Dockerfile", "COPY --chown=rails:rails --from=build /rails /rails"
    end
  end
end

class DeployDockerfileSsrBunTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    use_ssr = true
    package_manager = "bun"
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_bun_installed_in_build_stage_not_base
    run_generator do
      content = File.read(File.join(destination, "Dockerfile"))
      base_section = content[0...content.index("FROM base AS build")]
      refute base_section.include?("bun.sh/install"),
        "Bun should not be installed in base stage anymore"
      build_section = content[content.index("FROM base AS build")...content.index("FROM base AS branch-ssr-true")]
      assert build_section.include?("bun.sh/install"),
        "Bun should be installed in build stage"
    end
  end

  def test_branch_ssr_true_copies_bun_runtime
    run_generator do
      assert_file_contains "Dockerfile", "FROM base AS branch-ssr-true"
      assert_file_contains "Dockerfile", "COPY --from=build /usr/local/bun /usr/local/bun"
      assert_file_contains "Dockerfile", "ENV BUN_INSTALL=/usr/local/bun"
    end
  end

  def test_ssr_build_uses_bun_runner
    run_generator do
      assert_file_contains "Dockerfile", 'if [ "$SSR_ENABLED" = "true" ]; then bun run vite build --ssr'
    end
  end
end

class DeployDockerfileNoSsrTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_arg_ssr_enabled_defaults_false
    run_generator do
      assert_file_contains "Dockerfile", "ARG SSR_ENABLED=false"
    end
  end

  def test_branch_stages_still_present
    run_generator do
      assert_file_contains "Dockerfile", "FROM base AS branch-ssr-true"
      assert_file_contains "Dockerfile", "FROM base AS branch-ssr-false"
      assert_file_contains "Dockerfile", "FROM branch-ssr-${SSR_ENABLED} AS final"
    end
  end

  def test_node_runtime_copy_lives_in_branch_not_final
    run_generator do
      content = File.read(File.join(destination, "Dockerfile"))
      final_section = content[content.index("FROM branch-ssr-${SSR_ENABLED}")..]
      refute final_section.include?("/usr/local/node /usr/local/node"),
        "Node runtime copy belongs in branch-ssr-true, not in final"
    end
  end

  def test_ssr_build_step_present_but_gated_by_arg
    run_generator do
      assert_file_contains "Dockerfile", 'if [ "$SSR_ENABLED" = "true" ]'
    end
  end
end

class DeployDockerfileMissingTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    <%= include "deploy" %>
  CODE

  def test_skips_when_no_dockerfile
    run_generator do
      refute_file "Dockerfile"
    end
  end
end

class DeployCiWorkflowFreshAppTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    use_eslint = true
    use_typescript = true
    js_ext = "ts"
    file ".github/workflows/ci.yml", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_generates_complete_ci_with_lint_js
    run_generator do
      ci = File.read(File.join(destination, ".github/workflows/ci.yml"))
      refute ci.include?("scan_js"), "scan_js job should not exist"
      refute ci.include?("importmap"), "importmap reference should not exist"
      assert ci.include?("lint_js"), "lint_js job should exist"
    end
  end

  def test_lint_js_has_node_setup
    run_generator do
      assert_file_contains ".github/workflows/ci.yml", "setup-node"
      assert_file_contains ".github/workflows/ci.yml", "node-version: 22"
    end
  end

  def test_lint_js_has_eslint_steps
    run_generator do
      assert_file_contains ".github/workflows/ci.yml", "npm run lint"
      assert_file_contains ".github/workflows/ci.yml", "npm run format"
    end
  end

  def test_lint_js_has_type_check
    run_generator do
      assert_file_contains ".github/workflows/ci.yml", "npm run check"
    end
  end

  def test_test_job_has_node_setup
    run_generator do
      ci = File.read(File.join(destination, ".github/workflows/ci.yml"))
      test_section = ci[ci.index("  test:")..] || ""
      assert test_section.include?("setup-node"), "test job should have Node.js setup"
      assert test_section.include?("npm ci"), "test job should install JS deps"
    end
  end
end

class DeployCiWorkflowPostgresTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    db_adapter = "postgresql"
    file ".github/workflows/ci.yml", "placeholder"
    append_to_file "Gemfile", "gem \\"pg\\"\\n"
    <%= include "deploy" %>
  CODE

  def test_includes_postgres_service
    run_generator do
      ci = File.read(File.join(destination, ".github/workflows/ci.yml"))
      assert ci.include?("postgres:"), "Should have postgres service"
      assert ci.include?("POSTGRES_USER"), "Should have postgres env"
      assert ci.include?("DATABASE_URL: postgres://"), "Should have postgres DATABASE_URL"
    end
  end
end

class DeployCiRunnerStarterTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    use_eslint = true
    use_typescript = true
    use_starter_kit = true
    test_framework = "rspec"
    file "config/ci.rb", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_replaces_rails_default_with_vite_aware_runner
    run_generator do
      ci = File.read(File.join(destination, "config/ci.rb"))
      assert ci.include?('step "Tests: Rails", "bin/rspec"'), "rspec starter should run bin/rspec"
      assert ci.include?('step "Security: NPM vulnerability audit", "npm audit"'), "should audit npm"
      assert ci.include?('step "JavaScript: lint", "npm run lint"'), "should lint JS"
      assert ci.include?('step "JavaScript: types check", "npm run check"'), "should type-check"
      refute ci.include?("importmap"), "should drop the broken importmap audit step"
    end
  end
end

class DeployCiRunnerFoundationTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    file "config/ci.rb", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_omits_js_and_test_steps_without_features
    run_generator do
      ci = File.read(File.join(destination, "config/ci.rb"))
      refute ci.include?("JavaScript:"), "no JS steps without eslint/typescript"
      refute ci.include?("Tests: Rails"), "no test steps without a starter kit"
      refute ci.include?("importmap"), "should drop the broken importmap audit step"
      assert ci.include?('step "Security: NPM vulnerability audit", "npm audit"'), "still audits npm"
    end
  end
end

class DeployCiWorkflowExistingAppTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    fresh_app = false
    use_eslint = true
    file ".github/workflows/ci.yml", <<~YAML
      name: CI
      jobs:
        scan_js:
          runs-on: ubuntu-latest
          steps:
            - run: bin/importmap audit
        test:
          runs-on: ubuntu-latest
          steps:
            - run: bin/rails test
    YAML
    <%= include "deploy" %>
  CODE

  def test_removes_scan_js_from_existing_ci
    run_generator do
      ci = File.read(File.join(destination, ".github/workflows/ci.yml"))
      refute ci.include?("scan_js"), "scan_js should be removed"
      refute ci.include?("importmap"), "importmap should be removed"
      assert ci.include?("test:"), "test job should remain"
    end
  end

  def test_creates_separate_lint_js_workflow
    run_generator do
      assert_file ".github/workflows/lint_js.yml"
      assert_file_contains ".github/workflows/lint_js.yml", "lint_js"
      assert_file_contains ".github/workflows/lint_js.yml", "setup-node"
    end
  end
end

class DeployCiWorkflowMissingTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    <%= include "deploy" %>
  CODE

  def test_skips_when_no_ci_workflow
    run_generator do
      refute_file ".github/workflows/ci.yml"
    end
  end
end

class DeployDependabotTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    #{ADD_GEM}
    file ".github/dependabot.yml", <<~YAML
      version: 2
      updates:
        - package-ecosystem: bundler
          directory: "/"
          schedule:
            interval: weekly
    YAML
    <%= include "deploy" %>
  CODE

  def test_adds_npm_to_dependabot
    run_generator do
      assert_file_contains ".github/dependabot.yml", "npm"
    end
  end

  def test_keeps_existing_bundler_entry
    run_generator do
      assert_file_contains ".github/dependabot.yml", "bundler"
    end
  end
end

class DeployDependabotMissingTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    #{ADD_GEM}
    <%= include "deploy" %>
  CODE

  def test_skips_when_no_dependabot_file
    run_generator do
      refute_file ".github/dependabot.yml"
    end
  end
end

class DeployCiWorkflowSystemTestsMinitestTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    use_system_tests = true
    file ".github/workflows/ci.yml", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_installs_chrome_and_runs_system_tests
    run_generator do
      ci = File.read(File.join(destination, ".github/workflows/ci.yml"))
      assert ci.include?("google-chrome-stable"), "Should install chrome"
      assert ci.include?("bin/rails db:test:prepare test test:system"), "Should run test:system"
      assert ci.include?("Keep screenshots from failed system tests"), "Should upload screenshots"
      assert ci.include?("tmp/screenshots"), "Minitest screenshots live in tmp/screenshots"
    end
  end
end

class DeployCiWorkflowSystemTestsRspecTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    use_system_tests = true
    test_framework = "rspec"
    file ".github/workflows/ci.yml", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_runs_spec_and_uploads_capybara_screenshots
    run_generator do
      ci = File.read(File.join(destination, ".github/workflows/ci.yml"))
      assert ci.include?("google-chrome-stable"), "Should install chrome"
      assert ci.include?("bin/rails db:test:prepare spec"), "Should run the spec task"
      refute ci.include?("test:system"), "rspec runs system specs via the spec task"
      assert ci.include?("tmp/capybara"), "rspec screenshots live in tmp/capybara"
    end
  end
end

class DeployCiWorkflowNoSystemTestsTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    file ".github/workflows/ci.yml", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_omits_chrome_and_screenshots
    run_generator do
      ci = File.read(File.join(destination, ".github/workflows/ci.yml"))
      refute ci.include?("google-chrome-stable"), "No chrome without system tests"
      refute ci.include?("Keep screenshots"), "No screenshots step without system tests"
      assert ci.include?("bin/rails db:test:prepare test"), "Still runs unit tests"
    end
  end
end
