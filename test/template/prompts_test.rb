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
    ENV["INERTIA_ALBA"] = "0"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"

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

class PromptsAutoDetectFrameworkTest < GeneratorTestCase
  template <<~'CODE'
    fresh_app = true
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
    ENV["INERTIA_ESLINT"] = "0"
    ENV["INERTIA_SSR"] = "0"
    ENV["INERTIA_TYPELIZER"] = "0"
    ENV["INERTIA_ALBA"] = "0"
    ENV["INERTIA_TEST_FRAMEWORK"] = "minitest"

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

    <%= include "prompts" %>

    say "SHADCN=#{use_shadcn}"
  CODE

  def test_shadcn_disabled_without_tailwind
    run_generator do |output|
      assert_line_printed output, "SHADCN=false"
    end
  end
end
