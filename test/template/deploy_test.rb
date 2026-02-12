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

class DeployDockerfileSsrTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    use_ssr = true
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_ssr_enabled_default_is_true
    run_generator do
      assert_file_contains "Dockerfile", "SSR_ENABLED=true"
    end
  end

  def test_installs_node_in_base_stage
    run_generator do
      content = File.read(File.join(destination, "Dockerfile"))
      base_section = content[0...content.index("FROM base AS build")]
      assert base_section.include?("node-build"), "Node.js should be installed in base stage"
    end
  end

  def test_conditional_vite_ssr_build
    run_generator do
      assert_file_contains "Dockerfile", "vite build --ssr"
      assert_file_contains "Dockerfile", "SSR_ENABLED"
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

  def test_installs_bun_in_base_stage
    run_generator do
      content = File.read(File.join(destination, "Dockerfile"))
      base_section = content[0...content.index("FROM base AS build")]
      assert base_section.include?("bun.sh/install"), "Bun should be installed in base stage"
    end
  end
end

class DeployDockerfileNoSsrTest < GeneratorTestCase
  template <<~CODE
    #{GeneratorTestCase::DEPLOY_PREAMBLE}
    file "Dockerfile", "placeholder"
    <%= include "deploy" %>
  CODE

  def test_ssr_disabled_default_is_false
    run_generator do
      assert_file_contains "Dockerfile", "SSR_ENABLED=false"
    end
  end

  def test_still_installs_node_in_base
    run_generator do
      content = File.read(File.join(destination, "Dockerfile"))
      base_section = content[0...content.index("FROM base AS build")]
      assert base_section.include?("node-build"), "Node.js should be in base stage (SSR-ready)"
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
