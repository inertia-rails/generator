# frozen_string_literal: true

require_relative "../test_helper"

class PromptsEnvFrameworkTest < GeneratorTestCase
  template <<~'CODE'
    fresh_app = true
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    framework = nil
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    use_shadcn = false
    use_eslint = false
    use_ssr = false
    use_typelizer = false
    use_alba = false
    test_framework = "minitest"
    auth_strategy = "none"

    ENV["INERTIA_FRAMEWORK"] = "vue"
    ENV["INERTIA_STARTER_KIT"] = "0"
    ENV["INERTIA_TS"] = "0"
    ENV["INERTIA_TAILWIND"] = "0"
    ENV["INERTIA_ESLINT"] = "0"
    ENV["INERTIA_SSR"] = "0"
    ENV["INERTIA_TYPELIZER"] = "0"
    ENV["INERTIA_ALBA"] = "0"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"
    ENV["INERTIA_SYSTEM_TESTS"] = "0"

    <%= include "prompts" %>

    say "FRAMEWORK=#{framework}"
    say "STARTER=#{use_starter_kit}"
    say "TS=#{use_typescript}"
    say "TAILWIND=#{use_tailwind}"
    say "ESLINT=#{use_eslint}"
    say "SSR=#{use_ssr}"
  CODE

  def test_reads_framework_from_env
    run_generator do |output|
      assert_line_printed output, "FRAMEWORK=vue"
      assert_line_printed output, "Framework: vue (from env)"
    end
  end

  def test_foundation_options_from_env
    run_generator do |output|
      assert_line_printed output, "STARTER=false"
      assert_line_printed output, "TS=false"
      assert_line_printed output, "TAILWIND=false"
      assert_line_printed output, "ESLINT=false"
      assert_line_printed output, "SSR=false"
    end
  end
end

class PromptsInvalidFrameworkTest < GeneratorTestCase
  template <<~CODE
    fresh_app = true
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    framework = nil
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    use_shadcn = false
    use_eslint = false
    use_ssr = false
    use_typelizer = false
    use_alba = false
    test_framework = "minitest"
    auth_strategy = "none"

    ENV["INERTIA_FRAMEWORK"] = "angular"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"

    begin
      <%= include "prompts" %>
    rescue SystemExit
      say "EXITED"
    end
  CODE

  def test_rejects_invalid_framework
    run_generator do |output|
      assert_line_printed output, "Invalid INERTIA_FRAMEWORK=angular"
      assert_line_printed output, "EXITED"
    end
  end
end

class PromptsStarterKitForcesOptionsTest < GeneratorTestCase
  template <<~'CODE'
    fresh_app = true
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    framework = nil
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    use_shadcn = false
    use_eslint = false
    use_ssr = false
    use_typelizer = false
    use_alba = false
    test_framework = "minitest"
    auth_strategy = "none"

    ENV["INERTIA_FRAMEWORK"] = "react"
    ENV["INERTIA_STARTER_KIT"] = "1"
    ENV["INERTIA_SSR"] = "1"
    ENV["INERTIA_ALBA"] = "0"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"
    ENV["INERTIA_SYSTEM_TESTS"] = "0"

    <%= include "prompts" %>

    say "TS=#{use_typescript}"
    say "TAILWIND=#{use_tailwind}"
    say "SHADCN=#{use_shadcn}"
    say "ESLINT=#{use_eslint}"
    say "SSR=#{use_ssr}"
    say "TYPELIZER=#{use_typelizer}"
    say "AUTH=#{auth_strategy}"
  CODE

  def test_starter_kit_forces_all_options_on
    run_generator do |output|
      assert_line_printed output, "TS=true"
      assert_line_printed output, "TAILWIND=true"
      assert_line_printed output, "SHADCN=true"
      assert_line_printed output, "ESLINT=true"
      assert_line_printed output, "SSR=true"
      assert_line_printed output, "TYPELIZER=true"
      assert_line_printed output, "AUTH=authentication_zero"
    end
  end
end

class PromptsStarterKitSsrOptOutTest < GeneratorTestCase
  template <<~'CODE'
    fresh_app = true
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    framework = nil
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    use_shadcn = false
    use_eslint = false
    use_ssr = false
    use_typelizer = false
    use_alba = false
    test_framework = "minitest"
    auth_strategy = "none"

    ENV["INERTIA_FRAMEWORK"] = "react"
    ENV["INERTIA_STARTER_KIT"] = "1"
    ENV["INERTIA_SSR"] = "0"
    ENV["INERTIA_ALBA"] = "0"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"
    ENV["INERTIA_SYSTEM_TESTS"] = "0"

    <%= include "prompts" %>

    say "SSR=#{use_ssr}"
    say "ESLINT=#{use_eslint}"
    say "AUTH=#{auth_strategy}"
  CODE

  def test_starter_kit_respects_ssr_opt_out
    run_generator do |output|
      assert_line_printed output, "SSR=false"
      assert_line_printed output, "ESLINT=true"
      assert_line_printed output, "AUTH=authentication_zero"
    end
  end
end

class PromptsAutoDetectFrameworkTest < GeneratorTestCase
  template <<~'CODE'
    fresh_app = true
    interactive = false
    framework_detected = "svelte"
    typescript_detected = true
    tailwind_detected = true
    framework = nil
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    use_shadcn = false
    use_eslint = false
    use_ssr = false
    use_typelizer = false
    use_alba = false
    test_framework = "minitest"
    auth_strategy = "none"

    ENV.delete("INERTIA_FRAMEWORK")
    ENV.delete("INERTIA_TS")
    ENV.delete("INERTIA_TAILWIND")
    ENV["INERTIA_STARTER_KIT"] = "0"
    ENV["INERTIA_SHADCN"] = "0"
    ENV["INERTIA_ESLINT"] = "0"
    ENV["INERTIA_SSR"] = "0"
    ENV["INERTIA_TYPELIZER"] = "0"
    ENV["INERTIA_ALBA"] = "0"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"
    ENV["INERTIA_SYSTEM_TESTS"] = "0"

    <%= include "prompts" %>

    say "FRAMEWORK=#{framework}"
    say "TS=#{use_typescript}"
    say "TAILWIND=#{use_tailwind}"
  CODE

  def test_auto_detects_framework_and_features
    run_generator do |output|
      assert_line_printed output, "FRAMEWORK=svelte"
      assert_line_printed output, "Framework: svelte (auto-detected)"
      assert_line_printed output, "TS=true"
      assert_line_printed output, "TypeScript: yes (auto-detected)"
      assert_line_printed output, "TAILWIND=true"
      assert_line_printed output, "Tailwind CSS: yes (auto-detected)"
    end
  end
end

class PromptsShadcnRequiresTailwindTest < GeneratorTestCase
  template <<~'CODE'
    fresh_app = true
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    framework = nil
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    use_shadcn = false
    use_eslint = false
    use_ssr = false
    use_typelizer = false
    use_alba = false
    test_framework = "minitest"
    auth_strategy = "none"

    ENV["INERTIA_FRAMEWORK"] = "react"
    ENV["INERTIA_STARTER_KIT"] = "0"
    ENV["INERTIA_TS"] = "1"
    ENV["INERTIA_TAILWIND"] = "0"
    ENV["INERTIA_SHADCN"] = "1"
    ENV["INERTIA_ESLINT"] = "0"
    ENV["INERTIA_SSR"] = "0"
    ENV["INERTIA_TYPELIZER"] = "0"
    ENV["INERTIA_ALBA"] = "0"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"
    ENV["INERTIA_SYSTEM_TESTS"] = "0"

    <%= include "prompts" %>

    say "SHADCN=#{use_shadcn}"
  CODE

  def test_shadcn_disabled_without_tailwind
    run_generator do |output|
      assert_line_printed output, "SHADCN=false"
    end
  end
end

class PromptsStarterKitSystemTestsEnvTest < GeneratorTestCase
  template <<~'CODE'
    fresh_app = true
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    framework = nil
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    use_shadcn = false
    use_eslint = false
    use_ssr = false
    use_typelizer = false
    use_alba = false
    use_system_tests = false
    test_framework = "minitest"
    auth_strategy = "none"

    ENV["INERTIA_FRAMEWORK"] = "react"
    ENV["INERTIA_STARTER_KIT"] = "1"
    ENV["INERTIA_SSR"] = "1"
    ENV["INERTIA_ALBA"] = "0"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"
    ENV["INERTIA_SYSTEM_TESTS"] = "1"

    <%= include "prompts" %>

    say "SYSTEM_TESTS=#{use_system_tests}"
  CODE

  def test_starter_kit_reads_system_tests_from_env
    run_generator do |output|
      assert_line_printed output, "System tests: yes (from env)"
      assert_line_printed output, "SYSTEM_TESTS=true"
    end
  end
end

class PromptsNonInteractiveFailFastTest < GeneratorTestCase
  template <<~CODE
    fresh_app = true
    interactive = false
    framework_detected = nil
    typescript_detected = false
    tailwind_detected = false
    framework = nil
    use_starter_kit = false
    use_typescript = false
    use_tailwind = false
    use_shadcn = false
    use_eslint = false
    use_ssr = false
    use_typelizer = false
    use_alba = false
    test_framework = "minitest"
    auth_strategy = "none"

    ENV["INERTIA_FRAMEWORK"] = "react"
    ENV["INERTIA_STARTER_KIT"] = "0"
    ENV.delete("INERTIA_TS")
    ENV["INERTIA_TAILWIND"] = "0"
    ENV["INERTIA_ESLINT"] = "0"
    ENV["INERTIA_SSR"] = "0"
    ENV["INERTIA_TYPELIZER"] = "0"
    ENV["INERTIA_ALBA"] = "0"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"
    ENV["INERTIA_SYSTEM_TESTS"] = "0"

    begin
      <%= include "prompts" %>
    rescue SystemExit
      say "EXITED"
    end
  CODE

  def test_fails_fast_when_env_missing_and_not_interactive
    run_generator do |output|
      assert_line_printed output, "Non-interactive run: set INERTIA_TS=0|1."
      assert_line_printed output, "EXITED"
    end
  end
end
