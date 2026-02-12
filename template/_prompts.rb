# ─── Interactive Prompts ─────────────────────────────────────────────

say ""
say "⚡ Inertia Rails Setup", :cyan
say ""

# 1. Framework choice
if ENV.key?("INERTIA_FRAMEWORK")
  framework = ENV["INERTIA_FRAMEWORK"].downcase
  unless %w[react vue svelte].include?(framework)
    say "Invalid INERTIA_FRAMEWORK=#{framework}. Must be react, vue, or svelte.", :red
    exit(1)
  end
  say "  Framework: #{framework} (from env)"
elsif framework_detected
  framework = framework_detected
  say "  Framework: #{framework} (auto-detected)"
else
  framework = ask("Which framework?", :green, limited_to: %w[react vue svelte], default: "react")
end

# 2. Setup path (only for fresh apps)
if fresh_app
  if ENV.key?("INERTIA_STARTER_KIT")
    use_starter_kit = ENV["INERTIA_STARTER_KIT"] == "1"
    say "  Setup: #{use_starter_kit ? 'Starter Kit' : 'Foundation'} (from env)"
  else
    use_starter_kit = ask("Setup path?", :green,
      limited_to: %w[foundation starter_kit], default: "foundation") == "starter_kit"
  end
end

# Helper: resolve a boolean option from env, auto-detection, or interactive prompt
prompt_bool = ->(env_key, label, prompt_text, detected: false) {
  if ENV.key?(env_key)
    value = ENV[env_key] == "1"
    say "  #{label}: #{value ? 'yes' : 'no'} (from env)"
  elsif detected
    value = true
    say "  #{label}: yes (auto-detected)"
  else
    value = yes?("#{prompt_text} (y/n)", :green)
  end
  value
}

if use_starter_kit
  # Starter Kit: all options forced on
  use_typescript = true
  use_tailwind   = true
  use_shadcn     = true
  use_eslint     = true
  use_ssr        = true
  use_typelizer  = true
  auth_strategy  = "authentication_zero"

  ["TypeScript", "Tailwind CSS", "shadcn/ui", "ESLint", "SSR", "Route helpers"].each do |label|
    say "  #{label.ljust(15)} yes (starter kit)"
  end
  say "  Authentication: authentication_zero (starter kit)"
else
  # Foundation: individual option prompts
  use_typescript = prompt_bool.("INERTIA_TS", "TypeScript", "Use TypeScript?", detected: typescript_detected)
  use_tailwind   = prompt_bool.("INERTIA_TAILWIND", "Tailwind CSS", "Use Tailwind CSS v4?", detected: tailwind_detected)

  # shadcn/ui (only if Tailwind)
  if use_tailwind
    use_shadcn = prompt_bool.("INERTIA_SHADCN", "shadcn/ui", "Use shadcn/ui?")
  else
    use_shadcn = false
  end

  use_eslint    = prompt_bool.("INERTIA_ESLINT", "ESLint + Prettier", "Use ESLint + Prettier?")
  use_ssr       = prompt_bool.("INERTIA_SSR", "SSR", "Enable server-side rendering (SSR)?")
  use_typelizer = prompt_bool.("INERTIA_TYPELIZER", "Route helpers", "Route helpers? (Typelizer)")

  # No auth on Foundation path
  auth_strategy = "none"
end

# Alba (both paths)
alba_prompt = use_typescript ? "Typed serializers? (Alba)" : "Serializers? (Alba)"
use_alba = prompt_bool.("INERTIA_ALBA", "Serializers", alba_prompt)

# Test framework (both paths)
if ENV.key?("INERTIA_TEST_FRAMEWORK")
  test_framework = ENV["INERTIA_TEST_FRAMEWORK"].downcase
  unless %w[minitest rspec].include?(test_framework)
    say "Invalid INERTIA_TEST_FRAMEWORK=#{test_framework}. Must be minitest or rspec.", :red
    exit(1)
  end
  say "  Test framework: #{test_framework} (from env)"
else
  test_framework = ask("Test framework?", :green,
    limited_to: %w[minitest rspec], default: "minitest")
end

# Summary
say ""
say "━━━ Configuration ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", :cyan
say "  Setup:          #{use_starter_kit ? 'Starter Kit' : 'Foundation'}"
say "  Framework:      #{framework}"
say "  TypeScript:     #{use_typescript ? 'yes' : 'no'}"
say "  Tailwind CSS:   #{use_tailwind ? 'yes' : 'no'}"
say "  shadcn/ui:      #{use_shadcn ? 'yes' : 'no'}"
say "  ESLint:         #{use_eslint ? 'yes' : 'no'}"
say "  SSR:            #{use_ssr ? 'yes' : 'no'}"
say "  Route helpers:  #{use_typelizer ? 'yes' : 'no'}"
say "  Serializers:    #{use_alba ? 'yes' : 'no'}"
say "  Test framework: #{test_framework}"
say "  Authentication: #{auth_strategy}"
say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", :cyan
say ""
