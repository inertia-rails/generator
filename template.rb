# Inertia Rails Generator
# https://github.com/inertia-rails/generator
#
# Usage:
#   rails new myapp -m https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb
#   rails app:template LOCATION=https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb
#
# Non-interactive mode via env vars:
#   INERTIA_FRAMEWORK=react INERTIA_STARTER_KIT=1 rails new myapp -m https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb

require "json"

# ─── State Variables ────────────────────────────────────────────────

# Detection state (set by _detect.rb)
fresh_app                = nil
vite_installed           = false
framework_detected       = nil
typescript_detected      = false
tailwind_detected        = false
importmap_detected       = false
js_destination_detected  = nil
package_manager          = "npm"
db_adapter               = "sqlite3"

# User choices (set by _prompts.rb)
framework       = nil
use_starter_kit = false
use_typescript  = false
use_tailwind    = false
use_shadcn      = false
use_eslint      = false
use_ssr         = false
use_typelizer   = false
use_alba        = false
test_framework  = "minitest"
auth_strategy   = "none"

# Accumulation arrays (partials append, _finalize.rb batch-installs)
npm_packages         = []
npm_dev_packages     = []
gems_to_add          = []
vite_plugins         = []
post_install_commands = []
eslint_ignores       = []

# Lookup: package manager install commands
pm_install = {
  "npm"  => { install: "npm install",  dev_flag: "--save-dev", exec: "npx" },
  "yarn" => { install: "yarn add",     dev_flag: "--dev",      exec: "npx" },
  "pnpm" => { install: "pnpm add",     dev_flag: "--save-dev", exec: "pnpm dlx" },
  "bun"  => { install: "bun add",      dev_flag: "--dev",      exec: "bunx" }
}

# Glob pattern for finding vite config files
vite_config_glob = "vite.config.{ts,js,mjs,cjs,mts,cts}"

# Shared helpers
gem_in_gemfile = ->(name) {
  return false unless File.exist?("Gemfile")
  File.read("Gemfile").match?(/^\s*gem\s+['"]#{name}['"]/)
}

remove_gem = ->(name) {
  gsub_file "Gemfile", /^\s*gem\s+['"]#{Regexp.escape(name)}['"].*\n/, ""
}

bundle_run = ->(*cmds) {
  in_root do
    cmds.each { |cmd| run cmd }
  end
}

add_gem = ->(name, comment: nil, group: nil, github: nil, branch: nil) {
  return if gem_in_gemfile.(name)
  entry = "gem \"#{name}\""
  entry += ", github: \"#{github}\"" if github
  entry += ", branch: \"#{branch}\"" if branch
  if group
    groups = Array(group).map(&:inspect).join(", ")
    entry += ", group: [ #{groups} ]"
  end
  entry += " # #{comment}" if comment
  append_to_file "Gemfile", "#{entry}\n"
}

update_json_file = ->(path, &block) {
  return unless File.exist?(path)
  json = JSON.parse(File.read(path))
  block.call(json)
  File.write(path, JSON.pretty_generate(json) + "\n")
}

update_package_json = ->(&block) {
  update_json_file.call("package.json", &block)
}

append_with_blank_line = ->(path, content) {
  append_to_file path, "\n" unless File.read(path).end_with?("\n\n")
  append_to_file path, content
}

# ─── Phase 1: Detect + Prompt ──────────────────────────────────────

# ─── Detection ────────────────────────────────────────────────────────

say "🔍 Detecting existing setup...", :cyan

# Detect fresh app vs existing app (rails new -m ... vs rails app:template)
# Allow pre-set value (e.g. from tests) to take precedence
fresh_app = !ARGV.any? { |a| a.include?("app:template") } if fresh_app.nil?

say fresh_app ? "  Detected: fresh Rails app" : "  Detected: existing Rails app"

# Detect API-only mode
if options[:api]
  say "❌ Inertia requires a full Rails app (not API-only).", :red
  say "   Please re-run without --api or set config.api_only = false.", :red
  exit(1)
end

# Detect package manager from lock files
package_manager = if File.exist?("package-lock.json")
  "npm"
elsif File.exist?("bun.lockb") || File.exist?("bun.lock")
  "bun"
elsif File.exist?("pnpm-lock.yaml")
  "pnpm"
elsif File.exist?("yarn.lock")
  "yarn"
else
  "npm"
end

say "  Package manager: #{package_manager}"

# Blocker: jsbundling/cssbundling break assets:precompile when Vite replaces their build scripts
if gem_in_gemfile.("jsbundling-rails") || gem_in_gemfile.("cssbundling-rails")
  say ""
  say "❌ jsbundling-rails and/or cssbundling-rails detected.", :red
  say "   This generator sets up Vite, which conflicts with these gems.", :red
  say ""
  say "   Options:", :yellow
  say "     1. Migrate to Vite: https://vite-ruby.netlify.app/guide/migration", :yellow
  say "     2. Remove the conflicting gems and re-run this generator", :yellow
  say "     3. Set up Inertia manually: https://inertia-rails.dev/guide/server-side-setup", :yellow
  say ""
  exit(1)
end

# Existing app: detect what's already installed
unless fresh_app
  # Track importmap for post-install warning
  importmap_detected = gem_in_gemfile.("importmap-rails")

  # Detect Vite
  vite_installed = Dir.glob(vite_config_glob).any? && gem_in_gemfile.("rails_vite")
  say "  Rails Vite: #{vite_installed ? 'installed' : 'not installed'}"

  # Detect framework from package.json
  pkg = JSON.parse(File.read("package.json")) rescue {}
  deps = (pkg["dependencies"] || {}).merge(pkg["devDependencies"] || {})

  if deps.key?("@inertiajs/react") || deps.key?("react")
    framework_detected = "react"
  elsif deps.key?("@inertiajs/vue3") || deps.key?("vue")
    framework_detected = "vue"
  elsif deps.key?("@inertiajs/svelte") || deps.key?("svelte")
    framework_detected = "svelte"
  end

  say "  Framework: #{framework_detected || 'none detected'}"

  # Detect TypeScript
  typescript_detected = File.exist?("tsconfig.json")
  say "  TypeScript: #{typescript_detected ? 'detected' : 'not detected'}"

  # Detect Tailwind
  tailwind_detected = deps.key?("tailwindcss")
  say "  Tailwind CSS: #{tailwind_detected ? 'detected' : 'not detected'}"

  # Detect frontend source directory (vite-ruby/rails_vite convention is `entrypoints/`)
  js_destination_detected = %w[app/frontend app/javascript app/client].find { |p|
    Dir.exist?("#{p}/entrypoints")
  }
  say "  Frontend dir: #{js_destination_detected || 'app/javascript (default)'}"
end

# Detect database adapter (for Dockerfile / CI)
db_adapter = if gem_in_gemfile.("pg")
  "postgresql"
elsif gem_in_gemfile.("mysql2")
  "mysql2"
elsif gem_in_gemfile.("trilogy")
  "trilogy"
else
  "sqlite3"
end

say "  Detection complete ✓", :green
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

# Compute derived state
js_ext = use_typescript ? "ts" : "js"
component_ext = case framework
  when "react" then use_typescript ? "tsx" : "jsx"
  when "vue" then "vue"
  when "svelte" then "svelte"
end

js_destination_path = js_destination_detected || "app/javascript"

# ─── Phase 2: Core Infrastructure ──────────────────────────────────

# ─── Conflict Cleanup ─────────────────────────────────────────────────

if fresh_app
  # Remove default Rails gems that Inertia+Vite replaces
  %w[importmap-rails turbo-rails stimulus-rails].each do |name|
    if gem_in_gemfile.(name)
      say "  Removing #{name}...", :yellow
      remove_gem.(name)
    end
  end

  # Remove associated files
  remove_file "config/importmap.rb"
  remove_file "bin/importmap"
  remove_file "app/javascript/controllers"
  remove_file "app/assets/stylesheets/application.css"

  # Clean layout tags
  layout_path = "app/views/layouts/application.html.erb"
  if File.exist?(layout_path)
    gsub_file layout_path, /\s*<%=\s*javascript_importmap_tags\s*%>\s*\n/, "\n"
    gsub_file layout_path, /\s*<%=\s*javascript_include_tag\s+["']application["'].*%>\s*\n/, "\n"
    gsub_file layout_path, /\s*<%=\s*stylesheet_link_tag\s+["']application["'].*%>\s*\n/, "\n"
  end

  # Clean ApplicationController (Rails 8.1+)
  if File.exist?("app/controllers/application_controller.rb")
    gsub_file "app/controllers/application_controller.rb",
      /\s*# Changes to the importmap.*\n\s*stale_when_importmap_changes\n/, "\n"
  end
end
# ─── Rails Vite Installation ─────────────────────────────────────────

# Ensure package.json exists with app name and ESM type
unless File.exist?("package.json")
  say "  Creating package.json", :yellow
  File.write("package.json", <<~JSON)
    {
      "name": "#{app_name}",
      "private": true,
      "type": "module"
    }
  JSON
end

# Pin Vite 8 via overrides (some deps like @inertiajs/vite haven't updated peer deps yet)
update_package_json.call do |pkg|
  case package_manager
  when "pnpm"
    pkg["pnpm"] ||= {}
    (pkg["pnpm"]["overrides"] ||= {})["vite"] = "$vite"
  when "yarn"
    (pkg["resolutions"] ||= {})["vite"] = "$vite"
  else
    (pkg["overrides"] ||= {})["vite"] = "$vite"
  end
end

unless vite_installed
  say "📦 Setting up Rails Vite...", :cyan

  add_gem.("rails_vite", comment: "Vite integration [https://github.com/skryukov/rails_vite]")

  # Create entrypoints directory
  empty_directory "#{js_destination_path}/entrypoints"

  # Add npm dev dependencies
  npm_dev_packages.push("rails-vite-plugin", "vite@^8")

  # Add .gitignore entries
  if File.exist?(".gitignore")
    append_with_blank_line.(".gitignore", <<~GITIGNORE)
      # Vite
      /public/vite*
      node_modules
      *.local
    GITIGNORE
  end

  # Add package manager install to bin/setup
  if File.exist?("bin/setup")
    unless File.read("bin/setup").include?("#{package_manager} install")
      insert_into_file "bin/setup", "\n  system! \"#{package_manager} install\"",
        after: 'system("bundle check") || system!("bundle install")'
    end
  end

  vite_installed = true
  say "  Rails Vite configured ✓", :green
else
  say "  Rails Vite already installed, skipping", :green
end
# ─── TypeScript Configuration ────────────────────────────────────────

if use_typescript
  say "📦 Setting up TypeScript...", :cyan

  case framework
  when "react"
    npm_dev_packages.push("@types/react", "@types/react-dom", "typescript@~5.8")
    file "tsconfig.json", ERB.new(
    *[
  <<~'TCODE'
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./<%= js_destination_path %>/*"]
    }
  },
  "files": [],
  "references": [
    {
      "path": "./tsconfig.app.json"
    },
    {
      "path": "./tsconfig.node.json"
    }
  ]
}
  TCODE
  ], trim_mode: "<>").result(binding)
    file "tsconfig.app.json", ERB.new(
    *[
  <<~'TCODE'
{
  "compilerOptions": {
    "composite": true,
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.app.tsbuildinfo",
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,

    /* Bundler mode */
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",

    /* Linting */
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,

    /* Aliases */
    "paths": {
      "@/*": ["./<%= js_destination_path %>/*"]
    }
  },
  "include": ["<%= js_destination_path %>/**/*"]
}
  TCODE
  ], trim_mode: "<>").result(binding)
    file "tsconfig.node.json", ERB.new(
    *[
  <<~'TCODE'
{
  "compilerOptions": {
    "composite": true,
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.node.tsbuildinfo",
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "noEmit": true
  },
  "include": ["<%= Dir.glob("vite.config.{ts,mts}").first || "vite.config.ts" %>"]
}
  TCODE
  ], trim_mode: "<>").result(binding)
    check_script = "tsc -p tsconfig.app.json && tsc -p tsconfig.node.json"
  when "vue"
    npm_dev_packages.push("typescript@~5.8", "vue-tsc")
    file "tsconfig.json", ERB.new(
    *[
  <<~'TCODE'
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./<%= js_destination_path %>/*"]
    }
  },
  "files": [],
  "references": [
    {
      "path": "./tsconfig.app.json"
    },
    {
      "path": "./tsconfig.node.json"
    }
  ]
}
  TCODE
  ], trim_mode: "<>").result(binding)
    file "tsconfig.app.json", ERB.new(
    *[
  <<~'TCODE'
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "module": "ESNext",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "skipLibCheck": true,

    /* Bundler mode */
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "preserve",

    /* Linting */
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,

    /* Aliases */
    "paths": {
      "@/*": ["./<%= js_destination_path %>/*"]
    }
  },

  "include": ["<%= js_destination_path %>/**/*.ts", "<%= js_destination_path %>/**/*.tsx", "<%= js_destination_path %>/**/*.vue"]
}
  TCODE
  ], trim_mode: "<>").result(binding)
    file "tsconfig.node.json", ERB.new(
    *[
  <<~'TCODE'
{
  "compilerOptions": {
    "composite": true,
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.node.tsbuildinfo",
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "noEmit": true
  },
  "include": ["<%= Dir.glob("vite.config.{ts,mts}").first || "vite.config.ts" %>"]
}
  TCODE
  ], trim_mode: "<>").result(binding)
    check_script = "vue-tsc -p tsconfig.app.json && tsc -p tsconfig.node.json"
  when "svelte"
    npm_dev_packages.push("@tsconfig/svelte@5", "svelte-check", "typescript@~5.8", "tslib")
    file "tsconfig.json", ERB.new(
    *[
  <<~'TCODE'
{
  "extends": "@tsconfig/svelte/tsconfig.json",
  "compilerOptions": {
    "target": "ESNext",
    "useDefineForClassFields": true,
    "module": "ESNext",
    "resolveJsonModule": true,
    "allowJs": true,
    "checkJs": true,
    "isolatedModules": true,
    "moduleDetection": "force",

    /* Aliases */
    "baseUrl": ".",
    "paths": {
      "@": ["./<%= js_destination_path %>"],
      "@/*": ["./<%= js_destination_path %>/*"]
    }
  },

  "include": ["<%= js_destination_path %>/**/*.ts", "<%= js_destination_path %>/**/*.js", "<%= js_destination_path %>/**/*.svelte"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
  TCODE
  ], trim_mode: "<>").result(binding)
    file "tsconfig.node.json", ERB.new(
    *[
  <<~'TCODE'
{
  "compilerOptions": {
    "composite": true,
    "tsBuildInfoFile": "./node_modules/.tmp/tsconfig.node.tsbuildinfo",
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "noEmit": true
  },
  "include": ["<%= Dir.glob("vite.config.{ts,mts}").first || "vite.config.ts" %>"]
}
  TCODE
  ], trim_mode: "<>").result(binding)
    check_script = "svelte-check --tsconfig ./tsconfig.json && tsc -p tsconfig.node.json"
  end

  # Copy type definition files
  case framework
  when "react"
    file "#{js_destination_path}/types/vite-env.d.ts", ERB.new(
    *[
  <<~'TCODE'
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_APP_NAME: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
  TCODE
  ], trim_mode: "<>").result(binding)
  when "svelte"
    file "#{js_destination_path}/types/vite-env.d.ts", ERB.new(
    *[
  <<~'TCODE'
/// <reference types="svelte" />
/// <reference types="vite/client" />
  TCODE
  ], trim_mode: "<>").result(binding)
  else
    file "#{js_destination_path}/types/vite-env.d.ts", ERB.new(
    *[
  <<~'TCODE'
/// <reference types="vite/client" />
  TCODE
  ], trim_mode: "<>").result(binding)
  end
  file "#{js_destination_path}/types/globals.d.ts", ERB.new(
    *[
  <<~'TCODE'
import type { FlashData, SharedProps } from '@/types'

declare module '@inertiajs/core' {
  export interface InertiaConfig {
    sharedPageProps: SharedProps
    flashDataType: FlashData
    errorValueType: string[]
  }
}
  TCODE
  ], trim_mode: "<>").result(binding)
  file "#{js_destination_path}/types/index.ts", ERB.new(
    *[
  <<~'TCODE'
export type FlashData = {
  notice?: string
  alert?: string
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface SharedProps {}
  TCODE
  ], trim_mode: "<>").result(binding)

  # Add check script to package.json
  update_package_json.call do |pkg|
    pkg["scripts"] ||= {}
    pkg["scripts"]["check"] = check_script
  end

  say "  TypeScript configured ✓", :green
end
# ─── Tailwind CSS v4 ─────────────────────────────────────────────────

if use_tailwind
  unless tailwind_detected
    say "📦 Setting up Tailwind CSS v4...", :cyan

    npm_dev_packages.push("tailwindcss", "@tailwindcss/vite", "@tailwindcss/forms", "@tailwindcss/typography")

    vite_plugins << { import: "import tailwindcss from '@tailwindcss/vite'", call: "tailwindcss()" }

    # Create CSS entrypoint
    file "#{js_destination_path}/entrypoints/application.css", ERB.new(
    *[
  <<~'TCODE'
@import 'tailwindcss';

@plugin '@tailwindcss/typography';
@plugin '@tailwindcss/forms';
  TCODE
  ], trim_mode: "<>").result(binding)

    say "  Tailwind CSS v4 configured ✓", :green
  else
    say "  Tailwind CSS already installed, skipping", :green
  end
end

# ─── Phase 3: Inertia ──────────────────────────────────────────────

# ─── Inertia Core Setup ──────────────────────────────────────────────

say "📦 Setting up Inertia...", :cyan

# Add inertia_rails to Gemfile (installed in _finalize.rb with single bundle install)
unless gem_in_gemfile.("inertia_rails")
  append_to_file "Gemfile", <<~GEM
    gem "inertia_rails", "~> 3.19" # Inertia.js adapter [https://inertia-rails.dev]
  GEM
end

# Add Inertia Vite plugin (shared across all frameworks)
npm_dev_packages << "@inertiajs/vite@^3.0"

# Add framework-specific packages and plugins
case framework
when "react"
  npm_packages.push("@inertiajs/react@^3.0", "react", "react-dom")
  npm_dev_packages.push("@vitejs/plugin-react", "@rolldown/plugin-babel", "babel-plugin-react-compiler")
  vite_plugins << { import: "import react, { reactCompilerPreset } from '@vitejs/plugin-react'", call: "react()" }
  vite_plugins << { import: "import babel from '@rolldown/plugin-babel'", call: "babel({ presets: [reactCompilerPreset()] })" }
when "vue"
  npm_packages.push("@inertiajs/vue3@^3.0", "vue")
  npm_dev_packages.push("@vitejs/plugin-vue", "vite-plugin-vue-devtools")
  vite_plugins << { import: "import vue from '@vitejs/plugin-vue'", call: "vue()" }
  vite_plugins << { import: "import vueDevTools from 'vite-plugin-vue-devtools'", call: "vueDevTools({ appendTo: 'inertia.#{js_ext}' })" }
when "svelte"
  npm_packages.push("@inertiajs/svelte@^3.0", "svelte@5")
  npm_dev_packages << "@sveltejs/vite-plugin-svelte"
  vite_plugins << { import: "import { svelte } from '@sveltejs/vite-plugin-svelte'", call: "svelte()" }
  file "svelte.config.js", <<~JS
    import { vitePreprocess } from '@sveltejs/vite-plugin-svelte'

    export default {
      preprocess: vitePreprocess(),
    }
  JS
end

# Create initializer
file "config/initializers/inertia_rails.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

InertiaRails.configure do |config|
  config.version = RailsVite.digest
  config.encrypt_history = Rails.env.production?
  config.use_script_element_for_initial_page = true
  config.use_data_inertia_head_attribute = true
  config.always_include_errors_hash = true
<% if use_starter_kit %>
  config.parent_controller = "::InertiaController"
<% end %>
<% if use_ssr %>
  # SSR configuration
  config.ssr_enabled = true
<% end %>
end
  TCODE
  ], trim_mode: "<>").result(binding)

# Create InertiaController
file "app/controllers/inertia_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class InertiaController < ApplicationController
  # Share data with all Inertia responses
  # see https://inertia-rails.dev/guide/shared-data
  #   inertia_share user: -> { Current.user&.as_json(only: [:id, :name, :email]) }
end
  TCODE
  ], trim_mode: "<>").result(binding)

# Modify application layout
layout_file = "app/views/layouts/application.html.erb"
if File.exist?(layout_file)
  # Add vite_tags with all entrypoints in a single call
  unless File.read(layout_file).include?("vite_tags")
    inertia_entrypoint = case framework
      when "react" then "inertia.#{component_ext}"
      else "inertia.#{js_ext}"
    end

    vite_entries = []
    vite_entries << "\"application.css\"" if use_tailwind
    vite_entries << "\"#{inertia_entrypoint}\""

    insert_into_file layout_file,
      "    <%= vite_tags #{vite_entries.join(", ")} %>\n    <%= inertia_ssr_head %>\n",
      before: "  </head>"
  end

  # Add data-inertia to title tag (not for Svelte)
  unless framework == "svelte"
    gsub_file layout_file, /<title>/, "<title data-inertia>"
  end
end

say "  Inertia core configured ✓", :green
# ─── Framework-Specific Entrypoint ───────────────────────────────────

say "📦 Creating Inertia entrypoint...", :cyan

case framework
when "react"
  entrypoint_path = "#{js_destination_path}/entrypoints/inertia.#{component_ext}"
  if use_typescript
    file entrypoint_path, ERB.new(
    *[
  <<~'TCODE'
import { createInertiaApp } from '@inertiajs/react'

void createInertiaApp({
  strictMode: true,
  pages: '../pages',
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: 'brackets',
    }),
  },
})
  TCODE
  ], trim_mode: "<>").result(binding)
  else
    file entrypoint_path, ERB.new(
    *[
  <<~'TCODE'
import { createInertiaApp } from '@inertiajs/react'

createInertiaApp({
  strictMode: true,
  pages: '../pages',
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: 'brackets',
    }),
  },
})
  TCODE
  ], trim_mode: "<>").result(binding)
  end
when "vue"
  entrypoint_path = "#{js_destination_path}/entrypoints/inertia.#{js_ext}"
  if use_typescript
    file entrypoint_path, ERB.new(
    *[
  <<~'TCODE'
import { createInertiaApp } from '@inertiajs/vue3'

createInertiaApp({
  pages: '../pages',
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: 'brackets',
    }),
  },
})
  TCODE
  ], trim_mode: "<>").result(binding)
  else
    file entrypoint_path, ERB.new(
    *[
  <<~'TCODE'
import { createInertiaApp } from '@inertiajs/vue3'

createInertiaApp({
  pages: '../pages',
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: 'brackets',
    }),
  },
})
  TCODE
  ], trim_mode: "<>").result(binding)
  end
when "svelte"
  entrypoint_path = "#{js_destination_path}/entrypoints/inertia.#{js_ext}"
  if use_typescript
    file entrypoint_path, ERB.new(
    *[
  <<~'TCODE'
import { createInertiaApp } from '@inertiajs/svelte'

createInertiaApp({
  pages: '../pages',
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: 'brackets',
    }),
  },
})
  TCODE
  ], trim_mode: "<>").result(binding)
  else
    file entrypoint_path, ERB.new(
    *[
  <<~'TCODE'
import { createInertiaApp } from '@inertiajs/svelte'

createInertiaApp({
  pages: '../pages',
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: 'brackets',
    }),
  },
})
  TCODE
  ], trim_mode: "<>").result(binding)
  end
end

say "  Entrypoint created: #{entrypoint_path} ✓", :green

# ─── Phase 4: Tooling + UI ─────────────────────────────────────────

# ─── shadcn/ui ───────────────────────────────────────────────────────

if use_shadcn
  say "📦 Setting up shadcn/ui...", :cyan

  eslint_ignores << "components/ui/**"

  # Match what `shadcn init` / `shadcn-vue init` / `shadcn-svelte init` install
  npm_dev_packages.push("clsx", "tailwind-merge", "tw-animate-css")

  if use_typescript
    utils_content = ERB.new(
    *[
  <<~'TCODE'
import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
  TCODE
  ], trim_mode: "<>").result(binding)
  else
    utils_content = ERB.new(
    *[
  <<~'TCODE'
import { clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs) {
  return twMerge(clsx(inputs))
}
  TCODE
  ], trim_mode: "<>").result(binding)
  end

  case framework
  when "react"
    file "#{js_destination_path}/lib/utils.#{js_ext}", utils_content
    file "components.json", ERB.new(
    *[
  <<~'TCODE'
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": false,
  "tsx": <%= use_typescript %>,
  "tailwind": {
    "config": "",
    "css": "<%= js_destination_path %>/entrypoints/application.css",
    "baseColor": "neutral",
    "cssVariables": true,
    "prefix": ""
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  },
  "iconLibrary": "lucide"
}
  TCODE
  ], trim_mode: "<>").result(binding)
    npm_dev_packages.push("class-variance-authority", "lucide-react", "radix-ui")
  when "vue"
    file "#{js_destination_path}/lib/utils.#{js_ext}", utils_content
    file "components.json", ERB.new(
    *[
  <<~'TCODE'
{
  "$schema": "https://shadcn-vue.com/schema.json",
  "style": "new-york",
  "typescript": <%= use_typescript %>,
  "tailwind": {
    "config": "",
    "css": "<%= js_destination_path %>/entrypoints/application.css",
    "baseColor": "neutral",
    "cssVariables": true,
    "prefix": ""
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  },
  "iconLibrary": "lucide"
}
  TCODE
  ], trim_mode: "<>").result(binding)
    npm_dev_packages.push("class-variance-authority", "lucide-vue-next")
  when "svelte"
    # Svelte shadcn uses @/utils (not @/lib/utils) — the CLI generates additional
    # types (WithElementRef, WithoutChildren) in utils.ts that components depend on
    file "#{js_destination_path}/utils.#{js_ext}", utils_content
    file "components.json", ERB.new(
    *[
  <<~'TCODE'
{
  "$schema": "https://shadcn-svelte.com/schema.json",
  "tailwind": {
    "css": "<%= js_destination_path %>/entrypoints/application.css",
    "baseColor": "neutral"
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/utils",
    "ui": "@/components/ui",
    "hooks": "@/hooks",
    "lib": "@"
  },
  "typescript": <%= use_typescript %>,
  "registry": "https://shadcn-svelte.com/registry"
}
  TCODE
  ], trim_mode: "<>").result(binding)
    npm_dev_packages.push("@lucide/svelte", "tailwind-variants")
  end

  # JS projects need jsconfig.json for @ path alias (TS projects get this from tsconfig.json)
  unless use_typescript
    file "jsconfig.json", ERB.new(
    *[
  <<~'TCODE'
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./<%= js_destination_path %>/*"]
    }
  }
}
  TCODE
  ], trim_mode: "<>").result(binding)
  end

  # Build shadcn CLI command for post-install (needs npm packages installed first)
  if use_starter_kit
    shadcn_cli = case framework
      when "vue" then "shadcn-vue@latest"
      when "svelte" then "shadcn-svelte@latest"
      else "shadcn@latest"
    end

    shadcn_components = %w[
      alert avatar badge breadcrumb button card checkbox collapsible
      dialog dropdown-menu input label navigation-menu separator
      sheet sidebar skeleton sonner toggle toggle-group tooltip
    ]

    case framework
    when "react"
      # spinner and select are only available in the React shadcn registry
      shadcn_components.push("spinner", "select")
    end

    pm_exec = pm_install[package_manager][:exec]
    post_install_commands << "#{pm_exec} #{shadcn_cli} add #{shadcn_components.join(' ')} --yes --overwrite"
  end

  say "  shadcn/ui configured ✓", :green
end
# ─── Typelizer (route helpers) ────────────────────────────────────────

if use_typelizer
  say "📦 Setting up route helpers (Typelizer)...", :cyan

  add_gem.("typelizer")

  # Generated routes are committed so frontend-only workflows (npm ci && npm run
  # lint/check/build) work without Ruby. Typelizer still regenerates on boot.
  # Exclude from ESLint since it's generated code.
  eslint_ignores << "routes/**"

  say "  Route helpers configured ✓", :green
end

# ─── Phase 5: Starter Kit ─────────────────────────────────────────

# ─── Starter Kit Backend ──────────────────────────────────────────────

if use_starter_kit
  say "📦 Setting up Starter Kit backend...", :cyan

  # ─── Dependencies ────────────────────────────────────────────────
  gems_to_add << "bcrypt"
  gems_to_add << "authentication-zero"
  gems_to_add << {name: "letter_opener", group: :development}
  gems_to_add << {name: "capybara-lockstep", group: :test}

  # ─── Models, Controllers, Mailers, Views, Routes ───────────────
    file "app/controllers/application_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :authenticate

  private

  def authenticate
    redirect_to sign_in_path unless perform_authentication
  end

  def require_no_authentication
    return unless perform_authentication

    flash[:notice] = "You are already signed in"
    redirect_to root_path
  end

  def perform_authentication
    Current.session ||= Session.find_by_id(cookies.signed[:session_token])
  end

  def set_current_request_details
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/dashboard_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class DashboardController < InertiaController
  def index
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/home_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class HomeController < InertiaController
  skip_before_action :authenticate
  before_action :perform_authentication

  def index
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/identity/email_verifications_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class Identity::EmailVerificationsController < InertiaController
  skip_before_action :authenticate, only: :show

  before_action :set_user, only: :show

  def show
    @user.update! verified: true
    redirect_to root_path, notice: "Thank you for verifying your email address"
  end

  def create
    send_email_verification
    redirect_back_or_to root_path, notice: "We sent a verification email to your email address"
  end

  private

  def set_user
    @user = User.find_by_token_for!(:email_verification, params[:sid])
  rescue StandardError
    redirect_to settings_email_path, alert: "That email verification link is invalid"
  end

  def send_email_verification
    UserMailer.with(user: Current.user).email_verification.deliver_later
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/identity/password_resets_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class Identity::PasswordResetsController < InertiaController
  skip_before_action :authenticate

  before_action :set_user, only: %i[edit update]

  def new
  end

  def edit
<% if use_alba %>
    @email = @user.email
    @sid = params[:sid]
<% else %>
    render inertia: { email: @user.email, sid: params[:sid] }
<% end %>
  end

  def create
    if @user = User.find_by(email: params[:email], verified: true)
      send_password_reset_email
      redirect_to sign_in_path, notice: "Check your email for reset instructions"
    else
      redirect_to new_identity_password_reset_path, alert: "You can't reset your password until you verify your email"
    end
  end

  def update
    if @user.update(user_params)
      redirect_to sign_in_path, notice: "Your password was reset successfully. Please sign in"
    else
      redirect_to edit_identity_password_reset_path(sid: params[:sid]), inertia: { errors: @user.errors }
    end
  end

  private

  def set_user
    @user = User.find_by_token_for!(:password_reset, params[:sid])
  rescue StandardError
    redirect_to new_identity_password_reset_path, alert: "That password reset link is invalid"
  end

  def user_params
    params.permit(:password, :password_confirmation)
  end

  def send_password_reset_email
    UserMailer.with(user: @user).password_reset.deliver_later
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/inertia_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class InertiaController < ApplicationController
<% if use_alba %>
  include Alba::Inertia::Controller

  inertia_share { SharedPropsSerializer.new(self).to_inertia }
<% else %>
  inertia_config default_render: true
  inertia_share auth: {
        user: -> { Current.user.as_json(only: %i[id name email verified created_at updated_at]) },
        session: -> { Current.session.as_json(only: %i[id]) }
      }
<% end %>
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/sessions_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class SessionsController < InertiaController
  skip_before_action :authenticate, only: %i[new create]
  before_action :require_no_authentication, only: %i[new create]
  before_action :set_session, only: :destroy

  def new
  end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      @session = user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }

      redirect_to dashboard_path, notice: "Signed in successfully"
    else
      redirect_to sign_in_path, alert: "That email or password is incorrect"
    end
  end

  def destroy
    @session.destroy!
    Current.session = nil
    redirect_to settings_sessions_path, notice: "That session has been logged out", inertia: { clear_history: true }
  end

  private

  def set_session
    @session = Current.user.sessions.find(params[:id])
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/settings/emails_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class Settings::EmailsController < InertiaController
  before_action :set_user

  def show
  end

  def update
    if @user.update(user_params)
      redirect_to_success
    else
      redirect_to settings_email_path, inertia: { errors: @user.errors }
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def user_params
    params.permit(:email, :password_challenge).with_defaults(password_challenge: "")
  end

  def redirect_to_success
    if @user.email_previously_changed?
      resend_email_verification
      redirect_to settings_email_path, notice: "Your email has been changed"
    else
      redirect_to settings_email_path
    end
  end

  def resend_email_verification
    UserMailer.with(user: @user).email_verification.deliver_later
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/settings/passwords_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class Settings::PasswordsController < InertiaController
  before_action :set_user

  def show
  end

  def update
    if @user.update(user_params)
      redirect_to settings_password_path, notice: "Your password has been changed"
    else
      redirect_to settings_password_path, inertia: { errors: @user.errors }
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def user_params
    params.permit(:password, :password_confirmation, :password_challenge).with_defaults(password_challenge: "")
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/settings/profiles_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class Settings::ProfilesController < InertiaController
  before_action :set_user

  def show
  end

  def update
    if @user.update(user_params)
      redirect_to settings_profile_path, notice: "Your profile has been updated"
    else
      redirect_to settings_profile_path, inertia: { errors: @user.errors }
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def user_params
    params.permit(:name)
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/settings/sessions_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class Settings::SessionsController < InertiaController
  def index
<% if use_alba %>
    @sessions = Current.user.sessions.order(created_at: :desc)
<% else %>
    sessions = Current.user.sessions.order(created_at: :desc)

    render inertia: { sessions: sessions.as_json(only: %i[id user_agent ip_address created_at]) }
<% end %>
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/controllers/users_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class UsersController < InertiaController
  skip_before_action :authenticate, only: %i[new create]
  before_action :require_no_authentication, only: %i[new create]

  def new
<% unless use_alba %>
    @user = User.new
<% end %>
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session_record = @user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }

      send_email_verification
      redirect_to dashboard_path, notice: "Welcome! You have signed up successfully"
    else
      redirect_to sign_up_path, inertia: { errors: @user.errors }
    end
  end

  def destroy
    user = Current.user
    if user.authenticate(params[:password_challenge] || "")
      user.destroy!
      Current.session = nil
      redirect_to root_path, notice: "Your account has been deleted", inertia: { clear_history: true }
    else
      redirect_to settings_profile_path, inertia: { errors: { password_challenge: "Password challenge is invalid" } }
    end
  end

  private

  def user_params
    params.permit(:email, :name, :password, :password_confirmation)
  end

  def send_email_verification
    UserMailer.with(user: @user).email_verification.deliver_later
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/mailers/user_mailer.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @signed_id = @user.generate_token_for(:password_reset)

    mail to: @user.email, subject: "Reset your password"
  end

  def email_verification
    @user = params[:user]
    @signed_id = @user.generate_token_for(:email_verification)

    mail to: @user.email, subject: "Verify your email"
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/models/current.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user_agent, :ip_address

  delegate :user, to: :session, allow_nil: true
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/models/session.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class Session < ApplicationRecord
  belongs_to :user

  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/models/user.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end

  generates_token_for :password_reset, expires_in: 20.minutes do
    password_salt.last(10)
  end

  has_many :sessions, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, allow_nil: true, length: { minimum: 12 }

  normalizes :email, with: -> { _1.strip.downcase }

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  after_update if: :password_digest_previously_changed? do
    sessions.where.not(id: Current.session).delete_all
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/views/user_mailer/email_verification.html.erb", ERB.new(
    *[
  <<~'TCODE'
<p>Hey there,</p>

<p>This is to confirm that <%%= @user.email %> is the email you want to use on your account. If you ever lose your password, that's where we'll email a reset link.</p>

<p><strong>You must hit the link below to confirm that you received this email.</strong></p>

<p><%%= link_to "Yes, use this email for my account", identity_email_verification_url(sid: @signed_id) %></p>

<hr>

<p>Have questions or need help? Just reply to this email and our support team will help you sort it out.</p>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/views/user_mailer/password_reset.html.erb", ERB.new(
    *[
  <<~'TCODE'
<p>Hey there,</p>

<p>Can't remember your password for <strong><%%= @user.email %></strong>? That's OK, it happens. Just hit the link below to set a new one.</p>

<p><%%= link_to "Reset my password", edit_identity_password_reset_url(sid: @signed_id) %></p>

<p>If you did not request a password reset you can safely ignore this email, it expires in 20 minutes. Only someone with access to this email account can reset your password.</p>

<hr>

<p>Have questions or need help? Just reply to this email and our support team will help you sort it out.</p>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "config/routes.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

Rails.application.routes.draw do
  get  "sign_in", to: "sessions#new", as: :sign_in
  post "sign_in", to: "sessions#create"
  get  "sign_up", to: "users#new", as: :sign_up
  post "sign_up", to: "users#create"

  resources :sessions, only: [ :destroy ]
  resource :users, only: [ :destroy ]

  namespace :identity do
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset,     only: [ :new, :edit, :create, :update ]
  end

  get :dashboard, to: "dashboard#index"

  namespace :settings do
    resource :profile, only: [ :show, :update ]
    resource :password, only: [ :show, :update ]
    resource :email, only: [ :show, :update ]
    resources :sessions, only: [ :index ]
    inertia :appearance
  end

  root "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
  # ─── Migrations (need dynamic timestamps) ───────────────────────
  timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
  file "db/migrate/#{timestamp}_create_users.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name,            null: false
      t.string :email,           null: false, index: { unique: true }
      t.string :password_digest, null: false

      t.boolean :verified, null: false, default: false

      t.timestamps
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding)
  file "db/migrate/#{timestamp.to_i + 1}_create_sessions.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding)

  # ─── Alba Serializers (if enabled) ──────────────────────────────
  if use_alba
    file "app/serializers/auth_serializer.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class AuthSerializer < ApplicationSerializer
  one :user
  one :session
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/serializers/identity/password_resets_edit_serializer.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

module Identity
  class PasswordResetsEditSerializer < ApplicationSerializer
    attributes :email, :sid
    typelize email: :string, sid: :string?
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/serializers/session_serializer.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class SessionSerializer < ApplicationSerializer
  attributes :id, :user_agent, :ip_address, :created_at
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/serializers/settings/sessions_index_serializer.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

module Settings
  class SessionsIndexSerializer < ApplicationSerializer
    has_many :sessions
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/serializers/shared_props_serializer.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class SharedPropsSerializer < ApplicationSerializer
  one :auth, source: proc { Current }
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "app/serializers/user_serializer.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class UserSerializer < ApplicationSerializer
  attributes :id, :name, :email, :verified, :created_at, :updated_at

  typelize :string?
  attribute :avatar do |user|
    nil # Placeholder for avatar URL (e.g. Gravatar, Active Storage)
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true  end

  say "  Starter Kit backend configured ✓", :green
end
# ─── Starter Kit Frontend ──────────────────────────────────────────────

if use_starter_kit
  say "📦 Setting up Starter Kit frontend...", :cyan

  # ─── Additional npm packages ──────────────────────────────────────
  case framework
  when "react"
    npm_packages << "@headlessui/react"
  when "vue"
    npm_packages << "@vueuse/core"
  when "svelte"
    npm_packages << "mode-watcher"
  end

  # ─── CSS entrypoint (override with themed version) ───────────────
  file "#{js_destination_path}/entrypoints/application.css", ERB.new(
    *[
  <<~'TCODE'
@import "tailwindcss";

@import "tw-animate-css";
@plugin "@tailwindcss/typography";
@plugin "@tailwindcss/forms";

@custom-variant dark (&:is(.dark *));

:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.145 0 0);
  --popover: oklch(1 0 0);
  --popover-foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --secondary: oklch(0.97 0 0);
  --secondary-foreground: oklch(0.205 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.97 0 0);
  --accent-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --destructive-foreground: oklch(0.577 0.245 27.325);
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
  --chart-1: oklch(0.646 0.222 41.116);
  --chart-2: oklch(0.6 0.118 184.704);
  --chart-3: oklch(0.398 0.07 227.392);
  --chart-4: oklch(0.828 0.189 84.429);
  --chart-5: oklch(0.769 0.188 70.08);
  --radius: 0.625rem;
  --sidebar: oklch(0.985 0 0);
  --sidebar-foreground: oklch(0.145 0 0);
  --sidebar-primary: oklch(0.54 0.22 29.15);
  --sidebar-primary-foreground: oklch(0.985 0 0);
  --sidebar-accent: oklch(0.97 0 0);
  --sidebar-accent-foreground: oklch(0.205 0 0);
  --sidebar-border: oklch(0.922 0 0);
  --sidebar-ring: oklch(0.708 0 0);
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.145 0 0);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.145 0 0);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.985 0 0);
  --primary-foreground: oklch(0.205 0 0);
  --secondary: oklch(0.269 0 0);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.269 0 0);
  --muted-foreground: oklch(0.708 0 0);
  --accent: oklch(0.269 0 0);
  --accent-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.396 0.141 25.723);
  --destructive-foreground: oklch(0.637 0.237 25.331);
  --border: oklch(0.269 0 0);
  --input: oklch(0.269 0 0);
  --ring: oklch(0.439 0 0);
  --chart-1: oklch(0.488 0.243 264.376);
  --chart-2: oklch(0.696 0.17 162.48);
  --chart-3: oklch(0.769 0.188 70.08);
  --chart-4: oklch(0.627 0.265 303.9);
  --chart-5: oklch(0.645 0.246 16.439);
  --sidebar: oklch(0.205 0 0);
  --sidebar-foreground: oklch(0.985 0 0);
  --sidebar-primary: oklch(0.54 0.22 29.15);
  --sidebar-primary-foreground: oklch(0.985 0 0);
  --sidebar-accent: oklch(0.269 0 0);
  --sidebar-accent-foreground: oklch(0.985 0 0);
  --sidebar-border: oklch(0.269 0 0);
  --sidebar-ring: oklch(0.439 0 0);
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-destructive-foreground: var(--destructive-foreground);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
  --color-chart-1: var(--chart-1);
  --color-chart-2: var(--chart-2);
  --color-chart-3: var(--chart-3);
  --color-chart-4: var(--chart-4);
  --color-chart-5: var(--chart-5);
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
  --color-sidebar: var(--sidebar);
  --color-sidebar-foreground: var(--sidebar-foreground);
  --color-sidebar-primary: var(--sidebar-primary);
  --color-sidebar-primary-foreground: var(--sidebar-primary-foreground);
  --color-sidebar-accent: var(--sidebar-accent);
  --color-sidebar-accent-foreground: var(--sidebar-accent-foreground);
  --color-sidebar-border: var(--sidebar-border);
  --color-sidebar-ring: var(--sidebar-ring);
  --animate-accordion-down: accordion-down 0.2s ease-out;
  --animate-accordion-up: accordion-up 0.2s ease-out;

  @keyframes accordion-down {
    from {
      height: 0;
    }
    to {
      height: var(--radix-accordion-content-height);
    }
  }

  @keyframes accordion-up {
    from {
      height: var(--radix-accordion-content-height);
    }
    to {
      height: 0;
    }
  }
}

@layer base {
  * {
    @apply border-border outline-ring/50;
  }
  body {
    @apply bg-background text-foreground antialiased;
  }
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true

  # ─── Shared lib files (SSR helpers, storage) ────────────────────
  file "#{js_destination_path}/lib/browser.ts", ERB.new(
    *[
  <<~'TCODE'
export const isBrowser = typeof window !== "undefined"
  TCODE
  ], trim_mode: "<>").result(binding), force: true
  file "#{js_destination_path}/lib/storage.ts", ERB.new(
    *[
  <<~'TCODE'
import { isBrowser } from "./browser"

export function getItem(key: string): string | null {
  return isBrowser ? localStorage.getItem(key) : null
}

export function setItem(key: string, value: string): void {
  if (isBrowser) localStorage.setItem(key, value)
}

export function removeItem(key: string): void {
  if (isBrowser) localStorage.removeItem(key)
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true

  # ─── Framework-specific files (auto-generated from directory tree) ─
  case framework
  when "react"
    file "#{js_destination_path}/components/alert-error.tsx", ERB.new(
    *[
  <<~'TCODE'
import { AlertCircleIcon } from "lucide-react"

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"

export default function AlertError({
  errors,
  title,
}: {
  errors: string[]
  title?: string
}) {
  return (
    <Alert variant="destructive">
      <AlertCircleIcon />
      <AlertTitle>{title ?? "Something went wrong."}</AlertTitle>
      <AlertDescription>
        <ul className="list-inside list-disc text-sm">
          {Array.from(new Set(errors)).map((error, index) => (
            <li key={index}>{error}</li>
          ))}
        </ul>
      </AlertDescription>
    </Alert>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-content.tsx", ERB.new(
    *[
  <<~'TCODE'
import type * as React from "react"

import { SidebarInset } from "@/components/ui/sidebar"

type AppContentProps = {
  variant?: "header" | "sidebar"
} & React.ComponentProps<"main">

export function AppContent({
  variant = "header",
  children,
  ...props
}: AppContentProps) {
  if (variant === "sidebar") {
    return <SidebarInset {...props}>{children}</SidebarInset>
  }

  return (
    <main
      className="mx-auto flex h-full w-full max-w-7xl flex-1 flex-col gap-4 rounded-xl"
      {...props}
    >
      {children}
    </main>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-header.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link, usePage } from "@inertiajs/react"
import { BookOpen, Folder, LayoutGrid, Menu, Search } from "lucide-react"

import { Breadcrumbs } from "@/components/breadcrumbs"
import { Icon } from "@/components/icon"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuList,
  navigationMenuTriggerStyle,
} from "@/components/ui/navigation-menu"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { UserMenuContent } from "@/components/user-menu-content"
import { useInitials } from "@/hooks/use-initials"
import { cn } from "@/lib/utils"
import { dashboard } from "@/routes"
import type { BreadcrumbItem, NavItem } from "@/types"

import AppLogo from "./app-logo"
import AppLogoIcon from "./app-logo-icon"

const mainNavItems: NavItem[] = [
  {
    title: "Dashboard",
    href: dashboard.index().url,
    icon: LayoutGrid,
  },
]

const rightNavItems: NavItem[] = [
  {
    title: "Repository",
    href: "https://github.com/inertia-rails/react-starter-kit",
    icon: Folder,
  },
  {
    title: "Documentation",
    href: "https://inertia-rails.dev",
    icon: BookOpen,
  },
]

const activeItemStyles =
  "text-neutral-900 dark:bg-neutral-800 dark:text-neutral-100"

interface AppHeaderProps {
  breadcrumbs?: BreadcrumbItem[]
}

export function AppHeader({ breadcrumbs = [] }: AppHeaderProps) {
  const page = usePage()
  const { auth } = page.props
  const getInitials = useInitials()
  return (
    <>
      <div className="border-sidebar-border/80 border-b">
        <div className="mx-auto flex h-16 items-center px-4 md:max-w-7xl">
          {/* Mobile Menu */}
          <div className="lg:hidden">
            <Sheet>
              <SheetTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="mr-2 h-[34px] w-[34px]"
                >
                  <Menu className="h-5 w-5" />
                </Button>
              </SheetTrigger>
              <SheetContent
                side="left"
                className="bg-sidebar flex h-full w-64 flex-col items-stretch justify-between"
              >
                <SheetTitle className="sr-only">Navigation Menu</SheetTitle>
                <SheetHeader className="flex justify-start text-left">
                  <AppLogoIcon className="h-6 w-6 fill-current text-black dark:text-white" />
                </SheetHeader>
                <div className="flex h-full flex-1 flex-col space-y-4 p-4">
                  <div className="flex h-full flex-col justify-between text-sm">
                    <div className="flex flex-col space-y-4">
                      {mainNavItems.map((item) => (
                        <Link
                          key={item.title}
                          href={item.href}
                          className="flex items-center space-x-2 font-medium"
                        >
                          {item.icon && (
                            <Icon iconNode={item.icon} className="h-5 w-5" />
                          )}
                          <span>{item.title}</span>
                        </Link>
                      ))}
                    </div>

                    <div className="flex flex-col space-y-4">
                      {rightNavItems.map((item) => (
                        <a
                          key={item.title}
                          href={item.href}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="flex items-center space-x-2 font-medium"
                        >
                          {item.icon && (
                            <Icon iconNode={item.icon} className="h-5 w-5" />
                          )}
                          <span>{item.title}</span>
                        </a>
                      ))}
                    </div>
                  </div>
                </div>
              </SheetContent>
            </Sheet>
          </div>

          <Link
            href={dashboard.index()}
            prefetch
            className="flex items-center space-x-2"
          >
            <AppLogo />
          </Link>

          {/* Desktop Navigation */}
          <div className="ml-6 hidden h-full items-center space-x-6 lg:flex">
            <NavigationMenu className="flex h-full items-stretch">
              <NavigationMenuList className="flex h-full items-stretch space-x-2">
                {mainNavItems.map((item, index) => (
                  <NavigationMenuItem
                    key={index}
                    className="relative flex h-full items-center"
                  >
                    <Link
                      href={item.href}
                      className={cn(
                        navigationMenuTriggerStyle(),
                        page.url === item.href && activeItemStyles,
                        "h-9 cursor-pointer px-3",
                      )}
                    >
                      {item.icon && (
                        <Icon iconNode={item.icon} className="mr-2 h-4 w-4" />
                      )}
                      {item.title}
                    </Link>
                    {page.url === item.href && (
                      <div className="absolute bottom-0 left-0 h-0.5 w-full translate-y-px bg-black dark:bg-white"></div>
                    )}
                  </NavigationMenuItem>
                ))}
              </NavigationMenuList>
            </NavigationMenu>
          </div>

          <div className="ml-auto flex items-center space-x-2">
            <div className="relative flex items-center space-x-1">
              <Button
                variant="ghost"
                size="icon"
                className="group h-9 w-9 cursor-pointer"
              >
                <Search className="!size-5 opacity-80 group-hover:opacity-100" />
              </Button>
              <div className="hidden lg:flex">
                {rightNavItems.map((item) => (
                  <TooltipProvider key={item.title} delayDuration={0}>
                    <Tooltip>
                      <TooltipTrigger>
                        <a
                          href={item.href}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="group text-accent-foreground ring-offset-background hover:bg-accent hover:text-accent-foreground focus-visible:ring-ring ml-1 inline-flex h-9 w-9 items-center justify-center rounded-md bg-transparent p-0 text-sm font-medium transition-colors focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:outline-none disabled:pointer-events-none disabled:opacity-50"
                        >
                          <span className="sr-only">{item.title}</span>
                          {item.icon && (
                            <Icon
                              iconNode={item.icon}
                              className="size-5 opacity-80 group-hover:opacity-100"
                            />
                          )}
                        </a>
                      </TooltipTrigger>
                      <TooltipContent>
                        <p>{item.title}</p>
                      </TooltipContent>
                    </Tooltip>
                  </TooltipProvider>
                ))}
              </div>
            </div>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" className="size-10 rounded-full p-1">
                  <Avatar className="size-8 overflow-hidden rounded-full">
                    <AvatarImage src={auth.user.avatar} alt={auth.user.name} />
                    <AvatarFallback className="rounded-lg bg-neutral-200 text-black dark:bg-neutral-700 dark:text-white">
                      {getInitials(auth.user.name)}
                    </AvatarFallback>
                  </Avatar>
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent className="w-56" align="end">
                <UserMenuContent auth={auth} />
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>
      </div>
      {breadcrumbs.length > 1 && (
        <div className="border-sidebar-border/70 flex w-full border-b">
          <div className="mx-auto flex h-12 w-full items-center justify-start px-4 text-neutral-500 md:max-w-7xl">
            <Breadcrumbs breadcrumbs={breadcrumbs} />
          </div>
        </div>
      )}
    </>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-logo-icon.tsx", ERB.new(
    *[
  <<~'TCODE'
import type { SVGAttributes } from "react"

export default function AppLogoIcon(props: SVGAttributes<SVGElement>) {
  return (
    <svg
      height="32"
      viewBox="0 0 90 32"
      width="90"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <path
        fill="currentColor"
        d="m418.082357 25.9995403v4.1135034h-7.300339v1.89854h3.684072c1.972509 0 4.072534 1.4664311 4.197997 3.9665124l.005913.2373977v1.5821167c-.087824 3.007959-2.543121 4.1390018-4.071539 4.2011773l-.132371.0027328h-7.390745v-4.0909018l7.481152-.0226016v-1.9889467l-1.190107.0007441-.346911.0008254-.084566.0003251-.127643.0007097-.044785.0003793-.055764.0007949-.016378.0008259c.000518.0004173.013246.0008384.034343.0012518l.052212.000813c.030547.0003979.066903.0007803.105225.0011355l.078131.0006709-.155385-.0004701c-.31438-.001557-.85249-.0041098-1.729029-.0080055-1.775258 0-4.081832-1.3389153-4.219994-3.9549201l-.006518-.24899v-1.423905c0-2.6982402 2.278213-4.182853 4.065464-4.2678491l.161048-.003866zm-18.691579 0v11.8658752h6.170255v4.1361051h-10.735792v-16.0019803zm-6.441475 0v16.0019803h-4.588139v-16.0019803zm-10.803597 0c1.057758 0 4.04923.7305141 4.198142 3.951222l.005768.2526881v11.7980702h-4.271715v-2.8252084h-4.136105v2.8252084h-4.407325v-11.7980702c0-1.3184306 1.004082-4.0468495 3.946899-4.197411l.257011-.0064991zm-24.147177-.0027581 8.580186.0005749c.179372.0196801 4.753355.5702841 4.753355 5.5438436s-3.775694 5.3947112-3.92376 5.4093147l-.004472.0004216 5.00569 5.0505836h-6.374959l-3.726209-3.8608906v3.8608906h-4.309831zm22.418634-2.6971669.033418.0329283s-.384228.27122-.791058.610245c-12.837747-9.4927002-20.680526-5.0175701-23.144107-3.8196818-11.187826 6.2428065-7.954768 21.5678895-7.888988 21.8737669l.001006.0046469h-17.855317s.67805-6.6900935 5.4244-14.600677c4.74635-7.9105834 12.837747-13.9000252 19.414832-14.4876686 12.681632-1.2703535 24.110975 9.7062594 24.805814 10.3864403zm-31.111679 14.1815719 2.44098.881465c.113008.8852319.273103 1.7233771.441046 2.4882761l.101394.4499406-2.7122-.9718717c-.113009-.67805-.226017-1.6499217-.27122-2.84781zm31.506724-7.6619652h-1.514312c-1.128029 0-1.333125.5900716-1.370415.8046431l-.007251.056292-.000906.0152319-.00013 3.9153864h4.136105l-.000316-3.916479c-.004939-.0795522-.08331-.8750744-1.242775-.8750744zm-50.492125.339025 2.599192.94927c-.316423.731729-.719369 1.6711108-1.011998 2.4093289l-.118085.3028712-2.599192-.94927c.226017-.610245.700652-1.7403284 1.130083-2.7122001zm35.445121-.1434449h-3.456844v3.6588673h3.434397s.98767-.3815997.98767-1.8406572-.965223-1.8182101-.965223-1.8182101zm-15.442645-.7606218 1.62732 1.2882951c-.180814.705172-.318232 1.410344-.412255 2.115516l-.06238.528879-1.830735-1.4465067c.180813-.81366.384228-1.6499217.67805-2.4861834zm4.000495-6.3058651 1.017075 1.5369134c-.39779.4158707-.766649.8317413-1.095006 1.2707561l-.238493.3339623-1.08488-1.6273201c.40683-.5198383.881465-1.0396767 1.401304-1.5143117zm-16.182794-3.3450467 1.604719 1.4013034c-.40683.4237812-.800947.8729894-1.172815 1.3285542l-.364099.4569775-1.740328-1.4917101c.519838-.5650416 1.08488-1.1300833 1.672523-1.695125zm22.398252-.0904067.497237 1.4917101c-.524359.162732-1.048717.3688592-1.573076.6068095l-.393269.1842488-.519838-1.559515c.565041-.2486184 1.22049-.4972367 1.988946-.7232534zm5.28879-.54244c.578603.0361627 1.171671.1012555 1.779204.2068505l.458361.0869712-.090406 1.4013034c-.596684-.1265694-1.193368-.2097435-1.790052-.2495224l-.447513-.0216976zm-18.555968-6.2380601 1.017075 1.559515c-.440733.2203663-.868752.4661594-1.303128.7278443l-.437201.2666291-1.039676-1.5821167c.610245-.3616267 1.197888-.67805 1.76293-.9718717zm18.601172-.8588633c1.344799.3842283 1.923513.6474959 2.155025.7707625l.037336.0202958-.090406 1.5143117c-.482169-.1958811-.964338-.381717-1.453204-.5575078l-.739158-.2561522zm-8.633837-1.3334984.452033 1.3787017h-.226016c-.491587 0-.983173.0127134-1.474759.0476754l-.491587.0427313-.429431-1.3334984c.745855-.0904067 1.469108-.13561 2.16976-.13561z"
        transform="translate(-329 -15)"
      />
    </svg>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-logo.tsx", ERB.new(
    *[
  <<~'TCODE'
import AppLogoIcon from "./app-logo-icon"

export default function AppLogo() {
  return (
    <>
      <div className="bg-sidebar-primary text-sidebar-primary-foreground flex aspect-square size-8 items-center justify-center rounded-md">
        <AppLogoIcon className="size-5 fill-current text-white" />
      </div>
      <div className="ml-1 grid flex-1 text-left text-sm">
        <span className="mb-0.5 truncate leading-tight font-semibold">
          {import.meta.env.VITE_APP_NAME ?? "React Starter Kit"}
        </span>
      </div>
    </>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-shell.tsx", ERB.new(
    *[
  <<~'TCODE'
import { useState } from "react"

import { SidebarProvider } from "@/components/ui/sidebar"
import * as storage from "@/lib/storage"

interface AppShellProps {
  children: React.ReactNode
  variant?: "header" | "sidebar"
}

export function AppShell({ children, variant = "header" }: AppShellProps) {
  const [isOpen, setIsOpen] = useState(
    () => storage.getItem("sidebar") !== "false",
  )

  const handleSidebarChange = (open: boolean) => {
    setIsOpen(open)
    storage.setItem("sidebar", String(open))
  }

  if (variant === "header") {
    return <div className="flex min-h-screen w-full flex-col">{children}</div>
  }

  return (
    <SidebarProvider
      defaultOpen={isOpen}
      open={isOpen}
      onOpenChange={handleSidebarChange}
    >
      {children}
    </SidebarProvider>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-sidebar-header.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Breadcrumbs } from "@/components/breadcrumbs"
import { SidebarTrigger } from "@/components/ui/sidebar"
import type { BreadcrumbItem as BreadcrumbItemType } from "@/types"

export function AppSidebarHeader({
  breadcrumbs = [],
}: {
  breadcrumbs?: BreadcrumbItemType[]
}) {
  return (
    <header className="border-sidebar-border/50 flex h-16 shrink-0 items-center gap-2 border-b px-6 transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-12 md:px-4">
      <div className="flex items-center gap-2">
        <SidebarTrigger className="-ml-1" />
        <Breadcrumbs breadcrumbs={breadcrumbs} />
      </div>
    </header>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-sidebar.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link } from "@inertiajs/react"
import { BookOpen, Folder, LayoutGrid } from "lucide-react"

import { NavFooter } from "@/components/nav-footer"
import { NavMain } from "@/components/nav-main"
import { NavUser } from "@/components/nav-user"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { dashboard } from "@/routes"
import type { NavItem } from "@/types"

import AppLogo from "./app-logo"

const mainNavItems: NavItem[] = [
  {
    title: "Dashboard",
    href: dashboard.index().url,
    icon: LayoutGrid,
  },
]

const footerNavItems: NavItem[] = [
  {
    title: "Repository",
    href: "https://github.com/inertia-rails/react-starter-kit",
    icon: Folder,
  },
  {
    title: "Documentation",
    href: "https://inertia-rails.dev",
    icon: BookOpen,
  },
]

export function AppSidebar() {
  return (
    <Sidebar collapsible="icon" variant="inset">
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <Link href={dashboard.index()} prefetch>
                <AppLogo />
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>

      <SidebarContent>
        <NavMain items={mainNavItems} />
      </SidebarContent>

      <SidebarFooter>
        <NavFooter items={footerNavItems} className="mt-auto" />
        <NavUser />
      </SidebarFooter>
    </Sidebar>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/appearance-dropdown.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Monitor, Moon, Sun } from "lucide-react"
import type { HTMLAttributes } from "react"

import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { useAppearance } from "@/hooks/use-appearance"

export default function AppearanceToggleDropdown({
  className = "",
  ...props
}: HTMLAttributes<HTMLDivElement>) {
  const { appearance, updateAppearance } = useAppearance()

  const getCurrentIcon = () => {
    switch (appearance) {
      case "dark":
        return <Moon className="h-5 w-5" />
      case "light":
        return <Sun className="h-5 w-5" />
      default:
        return <Monitor className="h-5 w-5" />
    }
  }

  return (
    <div className={className} {...props}>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon" className="h-9 w-9 rounded-md">
            {getCurrentIcon()}
            <span className="sr-only">Toggle theme</span>
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => updateAppearance("light")}>
            <span className="flex items-center gap-2">
              <Sun className="h-5 w-5" />
              Light
            </span>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => updateAppearance("dark")}>
            <span className="flex items-center gap-2">
              <Moon className="h-5 w-5" />
              Dark
            </span>
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => updateAppearance("system")}>
            <span className="flex items-center gap-2">
              <Monitor className="h-5 w-5" />
              System
            </span>
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/appearance-tabs.tsx", ERB.new(
    *[
  <<~'TCODE'
import { type LucideIcon, Monitor, Moon, Sun } from "lucide-react"
import type { HTMLAttributes } from "react"

import { type Appearance, useAppearance } from "@/hooks/use-appearance"
import { cn } from "@/lib/utils"

export default function AppearanceToggleTab({
  className = "",
  ...props
}: HTMLAttributes<HTMLDivElement>) {
  const { appearance, updateAppearance } = useAppearance()

  const tabs: { value: Appearance; icon: LucideIcon; label: string }[] = [
    { value: "light", icon: Sun, label: "Light" },
    { value: "dark", icon: Moon, label: "Dark" },
    { value: "system", icon: Monitor, label: "System" },
  ]

  return (
    <div
      className={cn(
        "inline-flex gap-1 rounded-lg bg-neutral-100 p-1 dark:bg-neutral-800",
        className,
      )}
      {...props}
    >
      {tabs.map(({ value, icon: Icon, label }) => (
        <button
          key={value}
          onClick={() => updateAppearance(value)}
          className={cn(
            "flex items-center rounded-md px-3.5 py-1.5 transition-colors",
            appearance === value
              ? "bg-white shadow-xs dark:bg-neutral-700 dark:text-neutral-100"
              : "text-neutral-500 hover:bg-neutral-200/60 hover:text-black dark:text-neutral-400 dark:hover:bg-neutral-700/60",
          )}
        >
          <Icon className="-ml-1 h-4 w-4" />
          <span className="ml-1.5 text-sm">{label}</span>
        </button>
      ))}
    </div>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/breadcrumbs.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link } from "@inertiajs/react"
import { Fragment } from "react"

import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb"
import type { BreadcrumbItem as BreadcrumbItemType } from "@/types"

export function Breadcrumbs({
  breadcrumbs,
}: {
  breadcrumbs: BreadcrumbItemType[]
}) {
  return (
    <>
      {breadcrumbs.length > 0 && (
        <Breadcrumb>
          <BreadcrumbList>
            {breadcrumbs.map((item, index) => {
              const isLast = index === breadcrumbs.length - 1
              return (
                <Fragment key={index}>
                  <BreadcrumbItem>
                    {isLast ? (
                      <BreadcrumbPage>{item.title}</BreadcrumbPage>
                    ) : (
                      <BreadcrumbLink asChild>
                        <Link href={item.href}>{item.title}</Link>
                      </BreadcrumbLink>
                    )}
                  </BreadcrumbItem>
                  {!isLast && <BreadcrumbSeparator />}
                </Fragment>
              )
            })}
          </BreadcrumbList>
        </Breadcrumb>
      )}
    </>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/delete-user.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Form } from "@inertiajs/react"
import { useRef } from "react"

import HeadingSmall from "@/components/heading-small"
import InputError from "@/components/input-error"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { users } from "@/routes"

export default function DeleteUser() {
  const passwordInput = useRef<HTMLInputElement>(null)


  return (
    <div className="space-y-6">
      <HeadingSmall
        title="Delete account"
        description="Delete your account and all of its resources"
      />
      <div className="space-y-4 rounded-lg border border-red-100 bg-red-50 p-4 dark:border-red-200/10 dark:bg-red-700/10">
        <div className="relative space-y-0.5 text-red-600 dark:text-red-100">
          <p className="font-medium">Warning</p>
          <p className="text-sm">
            Please proceed with caution, this cannot be undone.
          </p>
        </div>

        <Dialog>
          <DialogTrigger asChild>
            <Button variant="destructive">Delete account</Button>
          </DialogTrigger>
          <DialogContent>
            <DialogTitle>
              Are you sure you want to delete your account?
            </DialogTitle>
            <DialogDescription>
              Once your account is deleted, all of its resources and data will
              also be permanently deleted. Please enter your password to confirm
              you would like to permanently delete your account.
            </DialogDescription>
            <Form
              action={users.destroy()}
              options={{
                preserveScroll: true,
              }}
              onError={() => passwordInput.current?.focus()}
              resetOnSuccess
              className="space-y-6"
            >
              {({ resetAndClearErrors, processing, errors }) => (
                <>
                  <div className="grid gap-2">
                    <Label htmlFor="password_challenge" className="sr-only">
                      Password
                    </Label>

                    <Input
                      id="password_challenge"
                      type="password"
                      name="password_challenge"
                      ref={passwordInput}
                      placeholder="Password"
                      autoComplete="current-password"
                    />

                    <InputError messages={errors.password_challenge} />
                  </div>

                  <DialogFooter>
                    <DialogClose asChild>
                      <Button
                        variant="secondary"
                        onClick={() => resetAndClearErrors()}
                      >
                        Cancel
                      </Button>
                    </DialogClose>

                    <Button variant="destructive" disabled={processing} asChild>
                      <button type="submit">Delete account</button>
                    </Button>
                  </DialogFooter>
                </>
              )}
            </Form>
          </DialogContent>
        </Dialog>
      </div>
    </div>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/heading-small.tsx", ERB.new(
    *[
  <<~'TCODE'
export default function HeadingSmall({
  title,
  description,
}: {
  title: string
  description?: string
}) {
  return (
    <header>
      <h3 className="mb-0.5 text-base font-medium">{title}</h3>
      {description && (
        <p className="text-muted-foreground text-sm">{description}</p>
      )}
    </header>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/heading.tsx", ERB.new(
    *[
  <<~'TCODE'
export default function Heading({
  title,
  description,
}: {
  title: string
  description?: string
}) {
  return (
    <div className="mb-8 space-y-0.5">
      <h2 className="text-xl font-semibold tracking-tight">{title}</h2>
      {description && (
        <p className="text-muted-foreground text-sm">{description}</p>
      )}
    </div>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/icon.tsx", ERB.new(
    *[
  <<~'TCODE'
import type { LucideProps } from "lucide-react"
import type { ComponentType } from "react"

import { cn } from "@/lib/utils"

type IconProps = {
  iconNode: ComponentType<LucideProps>
} & Omit<LucideProps, "ref">

export function Icon({
  iconNode: IconComponent,
  className,
  ...props
}: IconProps) {
  return <IconComponent className={cn("h-4 w-4", className)} {...props} />
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/input-error.tsx", ERB.new(
    *[
  <<~'TCODE'
import type { HTMLAttributes } from "react"

import { cn } from "@/lib/utils"

export default function InputError({
  messages,
  className = "",
  ...props
}: HTMLAttributes<HTMLParagraphElement> & { messages?: string[] }) {
  return messages ? (
    <p
      {...props}
      className={cn("text-sm text-red-600 dark:text-red-400", className)}
    >
      {messages.join(", ")}
    </p>
  ) : null
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/nav-footer.tsx", ERB.new(
    *[
  <<~'TCODE'
import type { ComponentPropsWithoutRef } from "react"

import { Icon } from "@/components/icon"
import {
  SidebarGroup,
  SidebarGroupContent,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import type { NavItem } from "@/types"

export function NavFooter({
  items,
  className,
  ...props
}: ComponentPropsWithoutRef<typeof SidebarGroup> & {
  items: NavItem[]
}) {
  return (
    <SidebarGroup
      {...props}
      className={`group-data-[collapsible=icon]:p-0 ${className ?? ""}`}
    >
      <SidebarGroupContent>
        <SidebarMenu>
          {items.map((item) => (
            <SidebarMenuItem key={item.title}>
              <SidebarMenuButton
                asChild
                className="text-neutral-600 hover:text-neutral-800 dark:text-neutral-300 dark:hover:text-neutral-100"
              >
                <a href={item.href} target="_blank" rel="noopener noreferrer">
                  {item.icon && (
                    <Icon iconNode={item.icon} className="h-5 w-5" />
                  )}
                  <span>{item.title}</span>
                </a>
              </SidebarMenuButton>
            </SidebarMenuItem>
          ))}
        </SidebarMenu>
      </SidebarGroupContent>
    </SidebarGroup>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/nav-main.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link, usePage } from "@inertiajs/react"

import {
  SidebarGroup,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import type { NavItem } from "@/types"

export function NavMain({ items = [] }: { items: NavItem[] }) {
  const page = usePage()
  return (
    <SidebarGroup className="px-2 py-0">
      <SidebarGroupLabel>Platform</SidebarGroupLabel>
      <SidebarMenu>
        {items.map((item) => (
          <SidebarMenuItem key={item.title}>
            <SidebarMenuButton
              asChild
              isActive={page.url.startsWith(item.href)}
              tooltip={{ children: item.title }}
            >
              <Link href={item.href} prefetch>
                {item.icon && <item.icon />}
                <span>{item.title}</span>
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        ))}
      </SidebarMenu>
    </SidebarGroup>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/nav-user.tsx", ERB.new(
    *[
  <<~'TCODE'
import { usePage } from "@inertiajs/react"
import { ChevronsUpDown } from "lucide-react"

import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from "@/components/ui/sidebar"
import { UserInfo } from "@/components/user-info"
import { UserMenuContent } from "@/components/user-menu-content"
import { useIsMobile } from "@/hooks/use-mobile"

export function NavUser() {
  const { auth } = usePage().props
  const { state } = useSidebar()
  const isMobile = useIsMobile()

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <SidebarMenuButton
              size="lg"
              className="text-sidebar-accent-foreground data-[state=open]:bg-sidebar-accent group"
            >
              <UserInfo user={auth.user} />
              <ChevronsUpDown className="ml-auto size-4" />
            </SidebarMenuButton>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            className="w-(--radix-dropdown-menu-trigger-width) min-w-56 rounded-lg"
            align="end"
            side={
              isMobile ? "bottom" : state === "collapsed" ? "left" : "bottom"
            }
          >
            <UserMenuContent auth={auth} />
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/placeholder-pattern.tsx", ERB.new(
    *[
  <<~'TCODE'
import { useId } from "react"

interface PlaceholderPatternProps {
  className?: string
}

export function PlaceholderPattern({ className }: PlaceholderPatternProps) {
  const patternId = useId()

  return (
    <svg className={className} fill="none">
      <defs>
        <pattern
          id={patternId}
          x="0"
          y="0"
          width="8"
          height="8"
          patternUnits="userSpaceOnUse"
        >
          <path d="M-1 5L5 -1M3 9L8.5 3.5" strokeWidth="0.5"></path>
        </pattern>
      </defs>
      <rect
        stroke="none"
        fill={`url(#${patternId})`}
        width="100%"
        height="100%"
      ></rect>
    </svg>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/text-link.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link } from "@inertiajs/react"
import type { ComponentProps } from "react"

import { cn } from "@/lib/utils"

type LinkProps = ComponentProps<typeof Link>

export default function TextLink({
  className = "",
  children,
  ...props
}: LinkProps) {
  return (
    <Link
      className={cn(
        "text-foreground underline decoration-neutral-300 underline-offset-4 transition-colors duration-300 ease-out hover:decoration-current! dark:decoration-neutral-500",
        className,
      )}
      {...props}
    >
      {children}
    </Link>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/user-info.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { useInitials } from "@/hooks/use-initials"
import type { User } from "@/types"

export function UserInfo({
  user,
  showEmail = false,
}: {
  user: User
  showEmail?: boolean
}) {
  const getInitials = useInitials()

  return (
    <>
      <Avatar className="h-8 w-8 overflow-hidden rounded-full">
        <AvatarImage src={user.avatar} alt={user.name} />
        <AvatarFallback className="rounded-lg bg-neutral-200 text-black dark:bg-neutral-700 dark:text-white">
          {getInitials(user.name)}
        </AvatarFallback>
      </Avatar>
      <div className="grid flex-1 text-left text-sm leading-tight">
        <span className="truncate font-medium">{user.name}</span>
        {showEmail && (
          <span className="text-muted-foreground truncate text-xs">
            {user.email}
          </span>
        )}
      </div>
    </>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/user-menu-content.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link, router } from "@inertiajs/react"
import { LogOut, Settings } from "lucide-react"

import {
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu"
import { UserInfo } from "@/components/user-info"
import { useMobileNavigation } from "@/hooks/use-mobile-navigation"
import { sessions, settingsProfiles } from "@/routes"
import type { User } from "@/types"

interface UserMenuContentProps {
  auth: {
    session: {
      id: number
    }
    user: User
  }
}

export function UserMenuContent({ auth }: UserMenuContentProps) {
  const { session, user } = auth
  const cleanup = useMobileNavigation()

  const handleLogout = () => {
    cleanup()
    router.flushAll()
  }

  return (
    <>
      <DropdownMenuLabel className="p-0 font-normal">
        <div className="flex items-center gap-2 px-1 py-1.5 text-left text-sm">
          <UserInfo user={user} showEmail={true} />
        </div>
      </DropdownMenuLabel>
      <DropdownMenuSeparator />
      <DropdownMenuGroup>
        <DropdownMenuItem asChild>
          <Link
            className="block w-full"
            href={settingsProfiles.show()}
            as="button"
            prefetch
            onClick={cleanup}
          >
            <Settings className="mr-2" />
            Settings
          </Link>
        </DropdownMenuItem>
      </DropdownMenuGroup>
      <DropdownMenuSeparator />
      <DropdownMenuItem asChild>
        <Link
          className="block w-full"
          href={sessions.destroy(session.id)}
          as="button"
          onClick={handleLogout}
        >
          <LogOut className="mr-2" />
          Log out
        </Link>
      </DropdownMenuItem>
    </>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/entrypoints/inertia.tsx", ERB.new(
    *[
  <<~'TCODE'
import { createInertiaApp } from "@inertiajs/react"

import { initializeTheme } from "@/hooks/use-appearance"
import PersistentLayout from "@/layouts/persistent-layout"

const appName = import.meta.env.VITE_APP_NAME ?? "React Starter Kit"

void createInertiaApp({
  title: (title) => (title ? `${title} - ${appName}` : appName),
  strictMode: true,
  pages: "../pages",
  layout: () => PersistentLayout,
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: "brackets",
    }),
  },
  progress: {
    color: "#4B5563",
  },
})

// This will set light / dark mode on load...
initializeTheme()
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/hooks/use-appearance.tsx", ERB.new(
    *[
  <<~'TCODE'
import { useCallback, useEffect, useState } from "react"

import { isBrowser } from "@/lib/browser"
import * as storage from "@/lib/storage"

export type Appearance = "light" | "dark" | "system"

const prefersDark = () =>
  isBrowser && window.matchMedia("(prefers-color-scheme: dark)").matches

const mediaQuery = () =>
  isBrowser ? window.matchMedia("(prefers-color-scheme: dark)") : null

const applyTheme = (appearance: Appearance) => {
  if (!isBrowser) return

  const isDark =
    appearance === "dark" || (appearance === "system" && prefersDark())

  document.documentElement.classList.toggle("dark", isDark)
  document.documentElement.style.colorScheme = isDark ? "dark" : "light"
}

const handleSystemThemeChange = () => {
  const currentAppearance = storage.getItem("appearance") as Appearance
  applyTheme(currentAppearance ?? "system")
}

export function initializeTheme() {
  const savedAppearance =
    (storage.getItem("appearance") as Appearance) || "system"

  applyTheme(savedAppearance)

  mediaQuery()?.addEventListener("change", handleSystemThemeChange)
}

export function useAppearance() {
  const [appearance, setAppearance] = useState<Appearance>(() => {
    const saved = storage.getItem("appearance") as Appearance | null
    return saved ?? "system"
  })

  const updateAppearance = useCallback((mode: Appearance) => {
    setAppearance(mode)
    if (mode === "system") {
      storage.removeItem("appearance")
    } else {
      storage.setItem("appearance", mode)
    }
    applyTheme(mode)
  }, [])

  useEffect(() => {
    applyTheme(appearance)

    return () =>
      mediaQuery()?.removeEventListener("change", handleSystemThemeChange)
  }, [appearance])

  return { appearance, updateAppearance } as const
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/hooks/use-clipboard.ts", ERB.new(
    *[
  <<~'TCODE'
// Credit: https://usehooks-ts.com/
import { useCallback, useState } from "react"

type CopiedValue = string | null

type CopyFn = (text: string) => Promise<boolean>

export function useClipboard(): [CopiedValue, CopyFn] {
  const [copiedText, setCopiedText] = useState<CopiedValue>(null)

  const copy: CopyFn = useCallback(async (text) => {
    if (!navigator?.clipboard) {
      console.warn("Clipboard not supported")

      return false
    }

    try {
      await navigator.clipboard.writeText(text)
      setCopiedText(text)

      return true
    } catch (error) {
      console.warn("Copy failed", error)
      setCopiedText(null)

      return false
    }
  }, [])

  return [copiedText, copy]
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/hooks/use-flash.tsx", ERB.new(
    *[
  <<~'TCODE'
import { usePage } from "@inertiajs/react"
import { useEffect } from "react"
import { toast } from "sonner"

import type { FlashData } from "@/types"

function showFlash(flash: FlashData) {
  if (flash.alert) toast.error(flash.alert)
  if (flash.notice) toast(flash.notice)
}

export function useFlash() {
  const { flash } = usePage()

  useEffect(() => {
    // setTimeout + cleanup prevents double-firing in React StrictMode
    const timeout = setTimeout(() => showFlash(flash), 0)
    return () => clearTimeout(timeout)
  }, [flash])
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/hooks/use-initials.tsx", ERB.new(
    *[
  <<~'TCODE'
import { useCallback } from "react"

export function useInitials() {
  return useCallback((fullName: string): string => {
    const names = fullName.trim().split(" ")

    if (names.length === 0) return ""
    if (names.length === 1) return names[0].charAt(0).toUpperCase()

    const firstInitial = names[0].charAt(0)
    const lastInitial = names[names.length - 1].charAt(0)

    return `${firstInitial}${lastInitial}`.toUpperCase()
  }, [])
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/hooks/use-mobile-navigation.ts", ERB.new(
    *[
  <<~'TCODE'
import { useCallback } from "react"

export function useMobileNavigation() {
  return useCallback(() => {
    // Remove pointer-events style from body...
    document.body.style.removeProperty("pointer-events")
  }, [])
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/hooks/use-mobile.ts", ERB.new(
    *[
  <<~'TCODE'
import { useSyncExternalStore } from "react"

import { isBrowser } from "@/lib/browser"

const MOBILE_BREAKPOINT = 768

const mql = isBrowser
  ? window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`)
  : null

function mediaQueryListener(callback: (event: MediaQueryListEvent) => void) {
  mql?.addEventListener("change", callback)

  return () => {
    mql?.removeEventListener("change", callback)
  }
}

function isSmallerThanBreakpoint() {
  return mql?.matches ?? false
}

export function useIsMobile() {
  return useSyncExternalStore(
    mediaQueryListener,
    isSmallerThanBreakpoint,
    () => false,
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/app-layout.tsx", ERB.new(
    *[
  <<~'TCODE'
import type { ReactNode } from "react"

import AppLayoutTemplate from "@/layouts/app/app-sidebar-layout"
import type { BreadcrumbItem } from "@/types"

interface AppLayoutProps {
  children: ReactNode
  breadcrumbs?: BreadcrumbItem[]
}

export default function AppLayout({
  children,
  breadcrumbs,
  ...props
}: AppLayoutProps) {
  return (
    <AppLayoutTemplate breadcrumbs={breadcrumbs} {...props}>
      {children}
    </AppLayoutTemplate>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/app/app-header-layout.tsx", ERB.new(
    *[
  <<~'TCODE'
import type { PropsWithChildren } from "react"

import { AppContent } from "@/components/app-content"
import { AppHeader } from "@/components/app-header"
import { AppShell } from "@/components/app-shell"
import type { BreadcrumbItem } from "@/types"

export default function AppHeaderLayout({
  children,
  breadcrumbs,
}: PropsWithChildren<{
  breadcrumbs?: BreadcrumbItem[]
}>) {
  return (
    <AppShell>
      <AppHeader breadcrumbs={breadcrumbs} />
      <AppContent>{children}</AppContent>
    </AppShell>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/app/app-sidebar-layout.tsx", ERB.new(
    *[
  <<~'TCODE'
import type { PropsWithChildren } from "react"

import { AppContent } from "@/components/app-content"
import { AppShell } from "@/components/app-shell"
import { AppSidebar } from "@/components/app-sidebar"
import { AppSidebarHeader } from "@/components/app-sidebar-header"
import type { BreadcrumbItem } from "@/types"

export default function AppSidebarLayout({
  children,
  breadcrumbs = [],
}: PropsWithChildren<{
  breadcrumbs?: BreadcrumbItem[]
}>) {
  return (
    <AppShell variant="sidebar">
      <AppSidebar />
      <AppContent variant="sidebar" className="overflow-x-hidden">
        <AppSidebarHeader breadcrumbs={breadcrumbs} />
        {children}
      </AppContent>
    </AppShell>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth-layout.tsx", ERB.new(
    *[
  <<~'TCODE'
import type { ReactNode } from "react"

import AuthLayoutTemplate from "@/layouts/auth/auth-simple-layout"

export default function AuthLayout({
  children,
  title,
  description,
  ...props
}: {
  children: ReactNode
  title: string
  description: string
}) {
  return (
    <AuthLayoutTemplate title={title} description={description} {...props}>
      {children}
    </AuthLayoutTemplate>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth/auth-card-layout.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link } from "@inertiajs/react"
import type { PropsWithChildren } from "react"

import AppLogoIcon from "@/components/app-logo-icon"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { home } from "@/routes"

export default function AuthCardLayout({
  children,
  title,
  description,
}: PropsWithChildren<{
  name?: string
  title?: string
  description?: string
}>) {
  return (
    <div className="bg-muted flex min-h-svh flex-col items-center justify-center gap-6 p-6 md:p-10">
      <div className="flex w-full max-w-md flex-col gap-6">
        <Link
          href={home.index()}
          className="flex items-center gap-2 self-center font-medium"
        >
          <div className="flex h-9 w-9 items-center justify-center">
            <AppLogoIcon className="size-9 fill-current text-black dark:text-white" />
          </div>
        </Link>

        <div className="flex flex-col gap-6">
          <Card className="rounded-xl">
            <CardHeader className="px-10 pt-8 pb-0 text-center">
              <CardTitle className="text-xl">{title}</CardTitle>
              <CardDescription>{description}</CardDescription>
            </CardHeader>
            <CardContent className="px-10 py-8">{children}</CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth/auth-simple-layout.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link } from "@inertiajs/react"
import type { PropsWithChildren } from "react"

import AppLogoIcon from "@/components/app-logo-icon"
import { home } from "@/routes"

interface AuthLayoutProps {
  name?: string
  title?: string
  description?: string
}

export default function AuthSimpleLayout({
  children,
  title,
  description,
}: PropsWithChildren<AuthLayoutProps>) {
  return (
    <div className="bg-background flex min-h-svh flex-col items-center justify-center gap-6 p-6 md:p-10">
      <div className="w-full max-w-sm">
        <div className="flex flex-col gap-8">
          <div className="flex flex-col items-center gap-4">
            <Link
              href={home.index()}
              className="flex flex-col items-center gap-2 font-medium"
            >
              <div className="mb-1 flex size-14 items-center justify-center rounded-md">
                <AppLogoIcon className="size-14 fill-current text-[var(--foreground)] dark:text-white" />
              </div>
              <span className="sr-only">{title}</span>
            </Link>

            <div className="space-y-2 text-center">
              <h1 className="text-xl font-medium">{title}</h1>
              <p className="text-muted-foreground text-center text-sm">
                {description}
              </p>
            </div>
          </div>
          {children}
        </div>
      </div>
    </div>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth/auth-split-layout.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link } from "@inertiajs/react"
import type { PropsWithChildren } from "react"

import AppLogoIcon from "@/components/app-logo-icon"
import { home } from "@/routes"

interface AuthLayoutProps {
  title?: string
  description?: string
}

export default function AuthSplitLayout({
  children,
  title,
  description,
}: PropsWithChildren<AuthLayoutProps>) {
  return (
    <div className="relative grid h-dvh flex-col items-center justify-center px-8 sm:px-0 lg:max-w-none lg:grid-cols-2 lg:px-0">
      <div className="bg-muted relative hidden h-full flex-col p-10 text-white lg:flex dark:border-r">
        <div className="absolute inset-0 bg-zinc-900" />
        <Link
          href={home.index()}
          className="relative z-20 flex items-center text-lg font-medium"
        >
          <AppLogoIcon className="mr-2 size-8 fill-current text-white" />
          {import.meta.env.VITE_APP_NAME ?? "React Starter Kit"}
        </Link>
        <div className="relative z-20 mt-auto">
          <blockquote className="space-y-2">
            <p className="text-lg">
              &ldquo;The One Person Framework. A toolkit so powerful that it
              allows a single individual to create modern applications upon
              which they might build a competitive business.&rdquo;
            </p>
            <footer className="text-sm text-neutral-300">DHH</footer>
          </blockquote>
        </div>
      </div>
      <div className="w-full lg:p-8">
        <div className="mx-auto flex w-full flex-col justify-center space-y-6 sm:w-[350px]">
          <Link
            href={home.index()}
            className="relative z-20 flex items-center justify-center lg:hidden"
          >
            <AppLogoIcon className="h-10 fill-current text-black sm:h-12" />
          </Link>
          <div className="flex flex-col items-start gap-2 text-left sm:items-center sm:text-center">
            <h1 className="text-xl font-medium">{title}</h1>
            <p className="text-muted-foreground text-sm text-balance">
              {description}
            </p>
          </div>
          {children}
        </div>
      </div>
    </div>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/persistent-layout.tsx", ERB.new(
    *[
  <<~'TCODE'
import type { ReactNode } from "react"

import { Toaster } from "@/components/ui/sonner"
import { useFlash } from "@/hooks/use-flash"

interface PersistentLayoutProps {
  children: ReactNode
}

export default function PersistentLayout({ children }: PersistentLayoutProps) {
  useFlash()
  return (
    <>
      {children}
      <Toaster richColors />
    </>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/settings/layout.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Link, usePage } from "@inertiajs/react"
import type { PropsWithChildren } from "react"

import Heading from "@/components/heading"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import { cn } from "@/lib/utils"
import {
  settingsAppearance,
  settingsEmails,
  settingsPasswords,
  settingsProfiles,
  settingsSessions,
} from "@/routes"
import type { NavItem } from "@/types"

const sidebarNavItems: NavItem[] = [
  {
    title: "Profile",
    href: settingsProfiles.show().url,
    icon: null,
  },
  {
    title: "Email",
    href: settingsEmails.show().url,
    icon: null,
  },
  {
    title: "Password",
    href: settingsPasswords.show().url,
    icon: null,
  },
  {
    title: "Sessions",
    href: settingsSessions.index().url,
    icon: null,
  },
  {
    title: "Appearance",
    href: settingsAppearance().url,
    icon: null,
  },
]

export default function SettingsLayout({ children }: PropsWithChildren) {
  const { url } = usePage()

  return (
    <div className="px-4 py-6">
      <Heading
        title="Settings"
        description="Manage your profile and account settings"
      />

      <div className="flex flex-col space-y-8 lg:flex-row lg:space-y-0 lg:space-x-12">
        <aside className="w-full max-w-xl lg:w-48">
          <nav className="flex flex-col space-y-1 space-x-0">
            {sidebarNavItems.map((item, index) => (
              <Button
                key={`${item.href}-${index}`}
                size="sm"
                variant="ghost"
                asChild
                className={cn("w-full justify-start", {
                  "bg-muted": url === item.href,
                })}
              >
                <Link href={item.href}>
                  {item.icon && <item.icon className="h-4 w-4" />}
                  {item.title}
                </Link>
              </Button>
            ))}
          </nav>
        </aside>

        <Separator className="my-6 md:hidden" />

        <div className="flex-1 md:max-w-2xl">
          <section className="max-w-xl space-y-12">{children}</section>
        </div>
      </div>
    </div>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/lib/utils.ts", ERB.new(
    *[
  <<~'TCODE'
import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/dashboard/index.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Head } from "@inertiajs/react"

import { PlaceholderPattern } from "@/components/placeholder-pattern"
import AppLayout from "@/layouts/app-layout"
import { dashboard } from "@/routes"
import type { BreadcrumbItem } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Dashboard",
    href: dashboard.index().url,
  },
]

export default function Dashboard() {
  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={breadcrumbs[breadcrumbs.length - 1].title} />

      <div className="flex h-full flex-1 flex-col gap-4 overflow-x-auto rounded-xl p-4">
        <div className="grid auto-rows-min gap-4 md:grid-cols-3">
          <div className="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border">
            <PlaceholderPattern className="absolute inset-0 size-full stroke-neutral-900/20 dark:stroke-neutral-100/20" />
          </div>
          <div className="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border">
            <PlaceholderPattern className="absolute inset-0 size-full stroke-neutral-900/20 dark:stroke-neutral-100/20" />
          </div>
          <div className="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border">
            <PlaceholderPattern className="absolute inset-0 size-full stroke-neutral-900/20 dark:stroke-neutral-100/20" />
          </div>
        </div>
        <div className="border-sidebar-border/70 dark:border-sidebar-border relative min-h-[100vh] flex-1 overflow-hidden rounded-xl border md:min-h-min">
          <PlaceholderPattern className="absolute inset-0 size-full stroke-neutral-900/20 dark:stroke-neutral-100/20" />
        </div>
      </div>
    </AppLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/home/index.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Head, Link, usePage } from "@inertiajs/react"

import AppLogoIcon from "@/components/app-logo-icon"
import { dashboard, sessions } from "@/routes"

export default function Welcome() {
  const page = usePage()
  const { auth } = page.props

  return (
    <>
      <Head title="Welcome">
        <link rel="preconnect" href="https://fonts.bunny.net" />
        <link
          href="https://fonts.bunny.net/css?family=instrument-sans:400,500,600"
          rel="stylesheet"
        />
      </Head>

      <div className="flex min-h-screen flex-col items-center bg-[#FDFDFC] p-6 text-[#1b1b18] lg:justify-center lg:p-8 dark:bg-[#0a0a0a]">
        <header className="mb-6 w-full max-w-[335px] text-sm not-has-[nav]:hidden lg:max-w-4xl">
          <nav className="flex items-center justify-end gap-4">
            {auth.user ? (
              <Link
                href={dashboard.index()}
                className="inline-block rounded-sm border border-[#19140035] px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#1915014a] dark:border-[#3E3E3A] dark:text-[#EDEDEC] dark:hover:border-[#62605b]"
              >
                Dashboard
              </Link>
            ) : (
              <>
                <Link
                  href={sessions.new()}
                  className="inline-block rounded-sm border border-transparent px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#19140035] dark:text-[#EDEDEC] dark:hover:border-[#3E3E3A]"
                >
                  Log in
                </Link>
              </>
            )}
          </nav>
        </header>

        <div className="flex w-full items-center justify-center opacity-100 transition-opacity duration-750 lg:grow starting:opacity-0">
          <main className="flex w-full max-w-[335px] flex-col-reverse lg:max-w-4xl lg:flex-row">
            <div className="flex-1 rounded-br-lg rounded-bl-lg bg-white p-6 pb-12 text-[13px] leading-[20px] shadow-[inset_0px_0px_0px_1px_rgba(26,26,0,0.16)] lg:rounded-tl-lg lg:rounded-br-none lg:p-20 dark:bg-[#161615] dark:text-[#EDEDEC] dark:shadow-[inset_0px_0px_0px_1px_#fffaed2d]">
              <h1 className="mb-1 font-medium">
                {import.meta.env.VITE_APP_NAME ?? "React Starter Kit"}
              </h1>
              <p className="mb-2 text-[#706f6c] dark:text-[#A1A09A]">
                Rails + Inertia.js + React + shadcn/ui
                <br />
                Here are some resources to begin:
              </p>

              <ul className="mb-4 flex flex-col lg:mb-6">
                {[
                  {
                    text: "Inertia Rails Docs",
                    href: "https://inertia-rails.dev",
                  },
                  {
                    text: "shadcn/ui Components",
                    href: "https://ui.shadcn.com",
                  },
                  {
                    text: "React Docs",
                    href: "https://react.dev",
                  },
                  {
                    text: "Rails Guides",
                    href: "https://guides.rubyonrails.org",
                  },
                ].map((resource, index) => (
                  <ResourceItem key={index} {...resource} />
                ))}
              </ul>

              <ul className="flex gap-3 text-sm leading-normal">
                <li>
                  <a
                    href="https://inertia-rails.dev"
                    target="_blank"
                    className="inline-block rounded-sm border border-black bg-[#1b1b18] px-5 py-1.5 text-sm leading-normal text-white hover:border-black hover:bg-black dark:border-[#eeeeec] dark:bg-[#eeeeec] dark:text-[#1C1C1A] dark:hover:border-white dark:hover:bg-white"
                    rel="noreferrer"
                  >
                    Learn More
                  </a>
                </li>
              </ul>
            </div>

            <div className="relative -mb-px aspect-[335/376] w-full shrink-0 overflow-hidden rounded-t-lg bg-[#D30001] p-10 text-white lg:mb-0 lg:-ml-px lg:aspect-auto lg:w-[438px] lg:rounded-t-none lg:rounded-r-lg">
              <AppLogoIcon className="h-full w-full" />
            </div>
          </main>
        </div>
      </div>
    </>
  )
}

function ResourceItem({ text, href }: { text: string; href: string }) {
  return (
    <li className="relative flex items-center gap-4 py-2">
      <span className="flex h-3.5 w-3.5 items-center justify-center rounded-full border border-[#e3e3e0] bg-[#FDFDFC] shadow-[0px_0px_1px_0px_rgba(0,0,0,0.03),0px_1px_2px_0px_rgba(0,0,0,0.06)] dark:border-[#3E3E3A] dark:bg-[#161615]">
        <span className="h-1.5 w-1.5 rounded-full bg-[#dbdbd7] dark:bg-[#3E3E3A]" />
      </span>
      <a
        href={href}
        target="_blank"
        className="inline-flex items-center space-x-1 font-medium text-[#f53003] underline underline-offset-4 dark:text-[#FF4433]"
        rel="noreferrer"
      >
        <span>{text}</span>
        <svg width={10} height={11} viewBox="0 0 10 11" className="h-2.5 w-2.5">
          <path
            d="M7.70833 6.95834V2.79167H3.54167M2.5 8L7.5 3.00001"
            stroke="currentColor"
            strokeLinecap="square"
          />
        </svg>
      </a>
    </li>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/identity/password_resets/edit.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Form, Head } from "@inertiajs/react"

import InputError from "@/components/input-error"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Spinner } from "@/components/ui/spinner"
import AuthLayout from "@/layouts/auth-layout"
import { identityPasswordResets } from "@/routes"

interface ResetPasswordProps {
  sid: string
  email: string
}

export default function ResetPassword({ sid, email }: ResetPasswordProps) {
  return (
    <AuthLayout
      title="Reset password"
      description="Please enter your new password below"
    >
      <Head title="Reset password" />
      <Form
        action={identityPasswordResets.update()}
        transform={(data) => ({ ...data, sid, email })}
        resetOnSuccess={["password", "password_confirmation"]}
      >
        {({ processing, errors }) => (
          <div className="grid gap-6">
            <div className="grid gap-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                name="email"
                autoComplete="email"
                value={email}
                className="mt-1 block w-full"
                readOnly
              />
              <InputError messages={errors.email} className="mt-2" />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="password">Password</Label>
              <Input
                id="password"
                type="password"
                name="password"
                autoComplete="new-password"
                className="mt-1 block w-full"
                autoFocus
                placeholder="Password"
              />
              <InputError messages={errors.password} />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="password_confirmation">Confirm password</Label>
              <Input
                id="password_confirmation"
                type="password"
                name="password_confirmation"
                autoComplete="new-password"
                className="mt-1 block w-full"
                placeholder="Confirm password"
              />
              <InputError
                messages={errors.password_confirmation}
                className="mt-2"
              />
            </div>

            <Button type="submit" className="mt-4 w-full" disabled={processing}>
              {processing && <Spinner />}
              Reset password
            </Button>
          </div>
        )}
      </Form>
    </AuthLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/identity/password_resets/new.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Form, Head } from "@inertiajs/react"

import InputError from "@/components/input-error"
import TextLink from "@/components/text-link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Spinner } from "@/components/ui/spinner"
import AuthLayout from "@/layouts/auth-layout"
import { identityPasswordResets, sessions } from "@/routes"

export default function ForgotPassword() {
  return (
    <AuthLayout
      title="Forgot password"
      description="Enter your email to receive a password reset link"
    >
      <Head title="Forgot password" />

      <div className="space-y-6">
        <Form action={identityPasswordResets.create()}>
          {({ processing, errors }) => (
            <>
              <div className="grid gap-2">
                <Label htmlFor="email">Email address</Label>
                <Input
                  id="email"
                  type="email"
                  name="email"
                  autoComplete="off"
                  autoFocus
                  placeholder="email@example.com"
                />
                <InputError messages={errors.email} />
              </div>

              <div className="my-6 flex items-center justify-start">
                <Button className="w-full" disabled={processing}>
                  {processing && <Spinner />}
                  Email password reset link
                </Button>
              </div>
            </>
          )}
        </Form>
        <div className="text-muted-foreground space-x-1 text-center text-sm">
          <span>Or, return to</span>
          <TextLink href={sessions.new()}>log in</TextLink>
        </div>
      </div>
    </AuthLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/sessions/new.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Form, Head } from "@inertiajs/react"

import InputError from "@/components/input-error"
import TextLink from "@/components/text-link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Spinner } from "@/components/ui/spinner"
import AuthLayout from "@/layouts/auth-layout"
import { identityPasswordResets, sessions, users } from "@/routes"

export default function Login() {
  return (
    <AuthLayout
      title="Log in to your account"
      description="Enter your email and password below to log in"
    >
      <Head title="Log in" />
      <Form
        action={sessions.create()}
        resetOnSuccess={["password"]}
        className="flex flex-col gap-6"
      >
        {({ processing, errors }) => (
          <>
            <div className="grid gap-6">
              <div className="grid gap-2">
                <Label htmlFor="email">Email address</Label>
                <Input
                  id="email"
                  name="email"
                  type="email"
                  required
                  autoFocus
                  tabIndex={1}
                  autoComplete="email"
                  placeholder="email@example.com"
                />
                <InputError messages={errors.email} />
              </div>

              <div className="grid gap-2">
                <div className="flex items-center">
                  <Label htmlFor="password">Password</Label>
                  <TextLink
                    href={identityPasswordResets.new()}
                    className="ml-auto text-sm"
                    tabIndex={5}
                  >
                    Forgot password?
                  </TextLink>
                </div>
                <Input
                  id="password"
                  type="password"
                  name="password"
                  required
                  tabIndex={2}
                  autoComplete="current-password"
                  placeholder="Password"
                />
                <InputError messages={errors.password} />
              </div>

              <Button
                type="submit"
                className="mt-4 w-full"
                tabIndex={4}
                disabled={processing}
              >
                {processing && <Spinner />}
                Log in
              </Button>
            </div>

            <div className="text-muted-foreground text-center text-sm">
              Don&apos;t have an account?{" "}
              <TextLink href={users.new()} tabIndex={5}>
                Sign up
              </TextLink>
            </div>
          </>
        )}
      </Form>
    </AuthLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/appearance.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Head } from "@inertiajs/react"

import AppearanceTabs from "@/components/appearance-tabs"
import HeadingSmall from "@/components/heading-small"
import AppLayout from "@/layouts/app-layout"
import SettingsLayout from "@/layouts/settings/layout"
import { settingsAppearance } from "@/routes"
import type { BreadcrumbItem } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Appearance settings",
    href: settingsAppearance().url,
  },
]

export default function Appearance() {
  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={breadcrumbs[breadcrumbs.length - 1].title} />

      <SettingsLayout>
        <div className="space-y-6">
          <HeadingSmall
            title="Appearance settings"
            description="Update your account's appearance settings"
          />
          <AppearanceTabs />
        </div>
      </SettingsLayout>
    </AppLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/emails/show.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Transition } from "@headlessui/react"
import { Form, Head, Link, usePage } from "@inertiajs/react"

import HeadingSmall from "@/components/heading-small"
import InputError from "@/components/input-error"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AppLayout from "@/layouts/app-layout"
import SettingsLayout from "@/layouts/settings/layout"
import { identityEmailVerifications, settingsEmails } from "@/routes"
import type { BreadcrumbItem } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Email settings",
    href: settingsEmails.show().url,
  },
]

export default function Email() {
  const { auth } = usePage().props

  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={breadcrumbs[breadcrumbs.length - 1].title} />

      <SettingsLayout>
        <div className="space-y-6">
          <HeadingSmall
            title="Update email"
            description="Update your email address and verify it"
          />

          <Form
            action={settingsEmails.update()}
            options={{
              preserveScroll: true,
            }}
            resetOnError={["password_challenge"]}
            resetOnSuccess={["password_challenge"]}
            className="space-y-6"
          >
            {({ errors, processing, recentlySuccessful }) => (
              <>
                <div className="grid gap-2">
                  <Label htmlFor="email">Email address</Label>

                  <Input
                    id="email"
                    type="email"
                    name="email"
                    className="mt-1 block w-full"
                    defaultValue={auth.user.email}
                    required
                    autoComplete="username"
                    placeholder="Email address"
                  />

                  <InputError className="mt-2" messages={errors.email} />
                </div>

                {!auth.user.verified && (
                  <div>
                    <p className="text-muted-foreground -mt-4 text-sm">
                      Your email address is unverified.{" "}
                      <Link
                        href={identityEmailVerifications.create()}
                        as="button"
                        className="text-foreground underline decoration-neutral-300 underline-offset-4 transition-colors duration-300 ease-out hover:decoration-current! dark:decoration-neutral-500"
                      >
                        Click here to resend the verification email.
                      </Link>
                    </p>
                  </div>
                )}

                <div className="grid gap-2">
                  <Label htmlFor="password_challenge">Current password</Label>

                  <Input
                    id="password_challenge"
                    name="password_challenge"
                    type="password"
                    className="mt-1 block w-full"
                    autoComplete="current-password"
                    placeholder="Current password"
                  />

                  <InputError messages={errors.password_challenge} />
                </div>

                <div className="flex items-center gap-4">
                  <Button disabled={processing}>Save</Button>

                  <Transition
                    show={recentlySuccessful}
                    enter="transition ease-in-out"
                    enterFrom="opacity-0"
                    leave="transition ease-in-out"
                    leaveTo="opacity-0"
                  >
                    <p className="text-sm text-neutral-600">Saved</p>
                  </Transition>
                </div>
              </>
            )}
          </Form>
        </div>
      </SettingsLayout>
    </AppLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/passwords/show.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Transition } from "@headlessui/react"
import { Form, Head } from "@inertiajs/react"

import HeadingSmall from "@/components/heading-small"
import InputError from "@/components/input-error"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AppLayout from "@/layouts/app-layout"
import SettingsLayout from "@/layouts/settings/layout"
import { settingsPasswords } from "@/routes"
import type { BreadcrumbItem } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Password settings",
    href: settingsPasswords.show().url,
  },
]

export default function Password() {
  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={breadcrumbs[breadcrumbs.length - 1].title} />

      <SettingsLayout>
        <div className="space-y-6">
          <HeadingSmall
            title="Update password"
            description="Ensure your account is using a long, random password to stay secure"
          />

          <Form
            action={settingsPasswords.update()}
            options={{
              preserveScroll: true,
            }}
            resetOnError
            resetOnSuccess
            className="space-y-6"
          >
            {({ errors, processing, recentlySuccessful }) => (
              <>
                <div className="grid gap-2">
                  <Label htmlFor="password_challenge">Current password</Label>

                  <Input
                    id="password_challenge"
                    name="password_challenge"
                    type="password"
                    className="mt-1 block w-full"
                    autoComplete="current-password"
                    placeholder="Current password"
                  />

                  <InputError messages={errors.password_challenge} />
                </div>

                <div className="grid gap-2">
                  <Label htmlFor="password">New password</Label>

                  <Input
                    id="password"
                    name="password"
                    type="password"
                    className="mt-1 block w-full"
                    autoComplete="new-password"
                    placeholder="New password"
                  />

                  <InputError messages={errors.password} />
                </div>

                <div className="grid gap-2">
                  <Label htmlFor="password_confirmation">
                    Confirm password
                  </Label>

                  <Input
                    id="password_confirmation"
                    name="password_confirmation"
                    type="password"
                    className="mt-1 block w-full"
                    autoComplete="new-password"
                    placeholder="Confirm password"
                  />

                  <InputError messages={errors.password_confirmation} />
                </div>

                <div className="flex items-center gap-4">
                  <Button disabled={processing}>Save password</Button>

                  <Transition
                    show={recentlySuccessful}
                    enter="transition ease-in-out"
                    enterFrom="opacity-0"
                    leave="transition ease-in-out"
                    leaveTo="opacity-0"
                  >
                    <p className="text-sm text-neutral-600">Saved</p>
                  </Transition>
                </div>
              </>
            )}
          </Form>
        </div>
      </SettingsLayout>
    </AppLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/profiles/show.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Transition } from "@headlessui/react"
import { Form, Head, usePage } from "@inertiajs/react"

import DeleteUser from "@/components/delete-user"
import HeadingSmall from "@/components/heading-small"
import InputError from "@/components/input-error"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AppLayout from "@/layouts/app-layout"
import SettingsLayout from "@/layouts/settings/layout"
import { settingsProfiles } from "@/routes"
import type { BreadcrumbItem } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Profile settings",
    href: settingsProfiles.show().url,
  },
]

export default function Profile() {
  const { auth } = usePage().props

  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={breadcrumbs[breadcrumbs.length - 1].title} />

      <SettingsLayout>
        <div className="space-y-6">
          <HeadingSmall
            title="Profile information"
            description="Update your name"
          />

          <Form
            action={settingsProfiles.update()}
            options={{
              preserveScroll: true,
            }}
            className="space-y-6"
          >
            {({ errors, processing, recentlySuccessful }) => (
              <>
                <div className="grid gap-2">
                  <Label htmlFor="name">Name</Label>

                  <Input
                    id="name"
                    name="name"
                    className="mt-1 block w-full"
                    defaultValue={auth.user.name}
                    required
                    autoComplete="name"
                    placeholder="Full name"
                  />

                  <InputError className="mt-2" messages={errors.name} />
                </div>

                <div className="flex items-center gap-4">
                  <Button disabled={processing}>Save</Button>

                  <Transition
                    show={recentlySuccessful}
                    enter="transition ease-in-out"
                    enterFrom="opacity-0"
                    leave="transition ease-in-out"
                    leaveTo="opacity-0"
                  >
                    <p className="text-sm text-neutral-600">Saved</p>
                  </Transition>
                </div>
              </>
            )}
          </Form>
        </div>

        <DeleteUser />
      </SettingsLayout>
    </AppLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/sessions/index.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Head, Link, usePage } from "@inertiajs/react"

import HeadingSmall from "@/components/heading-small"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import AppLayout from "@/layouts/app-layout"
import SettingsLayout from "@/layouts/settings/layout"
import { sessions as sessionsRoutes, settingsSessions } from "@/routes"
import type { BreadcrumbItem, Session } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Sessions",
    href: settingsSessions.index().url,
  },
]

interface SessionsProps {
  sessions: Session[]
}

export default function Sessions({ sessions }: SessionsProps) {
  const { auth } = usePage().props

  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={breadcrumbs[breadcrumbs.length - 1].title} />

      <SettingsLayout>
        <div className="space-y-6">
          <HeadingSmall
            title="Sessions"
            description="Manage your active sessions across devices"
          />

          <div className="space-y-4">
            {sessions.map((session) => (
              <div
                key={session.id}
                className="flex flex-col space-y-2 rounded-lg border p-4"
              >
                <div className="flex items-center justify-between">
                  <div className="space-y-1">
                    <p className="font-medium">
                      {session.user_agent}
                      {session.id === auth.session.id && (
                        <Badge variant="secondary" className="ml-2">
                          Current
                        </Badge>
                      )}
                    </p>
                    <p className="text-muted-foreground text-sm">
                      IP: {session.ip_address}
                    </p>
                    <p className="text-muted-foreground text-sm">
                      Active since:{" "}
                      {new Date(session.created_at).toLocaleString()}
                    </p>
                  </div>
                  {session.id !== auth.session.id && (
                    <Button variant="destructive" asChild>
                      <Link
                        href={sessionsRoutes.destroy(session.id)}
                        as="button"
                      >
                        Log out
                      </Link>
                    </Button>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      </SettingsLayout>
    </AppLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/users/new.tsx", ERB.new(
    *[
  <<~'TCODE'
import { Form, Head } from "@inertiajs/react"

import InputError from "@/components/input-error"
import TextLink from "@/components/text-link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Spinner } from "@/components/ui/spinner"
import AuthLayout from "@/layouts/auth-layout"
import { sessions, users } from "@/routes"

export default function Register() {
  return (
    <AuthLayout
      title="Create an account"
      description="Enter your details below to create your account"
    >
      <Head title="Register" />
      <Form
        action={users.create()}
        resetOnSuccess={["password", "password_confirmation"]}
        disableWhileProcessing
        className="flex flex-col gap-6"
      >
        {({ processing, errors }) => (
          <>
            <div className="grid gap-6">
              <div className="grid gap-2">
                <Label htmlFor="name">Name</Label>
                <Input
                  id="name"
                  type="text"
                  name="name"
                  required
                  autoFocus
                  tabIndex={1}
                  autoComplete="name"
                  disabled={processing}
                  placeholder="Full name"
                />
                <InputError messages={errors.name} className="mt-2" />
              </div>

              <div className="grid gap-2">
                <Label htmlFor="email">Email address</Label>
                <Input
                  id="email"
                  type="email"
                  name="email"
                  required
                  tabIndex={2}
                  autoComplete="email"
                  placeholder="email@example.com"
                />
                <InputError messages={errors.email} />
              </div>

              <div className="grid gap-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  name="password"
                  required
                  tabIndex={3}
                  autoComplete="new-password"
                  placeholder="Password"
                />
                <InputError messages={errors.password} />
              </div>

              <div className="grid gap-2">
                <Label htmlFor="password_confirmation">Confirm password</Label>
                <Input
                  id="password_confirmation"
                  type="password"
                  name="password_confirmation"
                  required
                  tabIndex={4}
                  autoComplete="new-password"
                  placeholder="Confirm password"
                />
                <InputError messages={errors.password_confirmation} />
              </div>

              <Button type="submit" className="mt-2 w-full" tabIndex={5}>
                {processing && <Spinner />}
                Create account
              </Button>
            </div>

            <div className="text-muted-foreground text-center text-sm">
              Already have an account?{" "}
              <TextLink href={sessions.new()} tabIndex={6}>
                Log in
              </TextLink>
            </div>
          </>
        )}
      </Form>
    </AuthLayout>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/types/index.ts", ERB.new(
    *[
  <<~'TCODE'
import type { LucideIcon } from "lucide-react"

export interface Auth {
  user: User
  session: Pick<Session, "id">
}

export interface BreadcrumbItem {
  title: string
  href: string
}

export interface NavItem {
  title: string
  href: string
  icon?: LucideIcon | null
  isActive?: boolean
}

export interface FlashData {
  alert?: string
  notice?: string
}

export interface SharedProps {
  auth: Auth
}

export interface User {
  id: number
  name: string
  email: string
  avatar?: string
  verified: boolean
  created_at: string
  updated_at: string
  [key: string]: unknown // This allows for additional properties...
}

export interface Session {
  id: number
  user_agent: string
  ip_address: string
  created_at: string
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true  when "vue"
    file "#{js_destination_path}/components/AppContent.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { computed } from "vue"

import { SidebarInset } from "@/components/ui/sidebar"

interface Props {
  variant?: "header" | "sidebar"
  class?: string
}

const props = defineProps<Props>()
const className = computed(() => props.class)
</script>

<template>
  <SidebarInset v-if="props.variant === 'sidebar'" :class="className">
    <slot />
  </SidebarInset>
  <main
    v-else
    class="mx-auto flex h-full w-full max-w-7xl flex-1 flex-col gap-4 rounded-xl"
    :class="className"
  >
    <slot />
  </main>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/AppHeader.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Link, usePage } from "@inertiajs/vue3"
import { BookOpen, Folder, LayoutGrid, Menu, Search } from "lucide-vue-next"
import { computed } from "vue"

import AppLogo from "@/components/AppLogo.vue"
import AppLogoIcon from "@/components/AppLogoIcon.vue"
import Breadcrumbs from "@/components/Breadcrumbs.vue"
import UserMenuContent from "@/components/UserMenuContent.vue"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuList,
  navigationMenuTriggerStyle,
} from "@/components/ui/navigation-menu"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { getInitials } from "@/composables/useInitials"
import { dashboard } from "@/routes"
import type { BreadcrumbItem, NavItem } from "@/types"

interface Props {
  breadcrumbs?: BreadcrumbItem[]
}

const props = withDefaults(defineProps<Props>(), {
  breadcrumbs: () => [],
})

const page = usePage()
const auth = computed(() => page.props.auth)

const isCurrentRoute = computed(() => (url: string) => page.url === url)

const activeItemStyles = computed(
  () => (url: string) =>
    isCurrentRoute.value(url)
      ? "text-neutral-900 dark:bg-neutral-800 dark:text-neutral-100"
      : "",
)

const mainNavItems: NavItem[] = [
  {
    title: "Dashboard",
    href: "/dashboard",
    icon: LayoutGrid,
  },
]

const rightNavItems: NavItem[] = [
  {
    title: "Repository",
    href: "https://github.com/inertia-rails/vue-starter-kit",
    icon: Folder,
  },
  {
    title: "Documentation",
    href: "https://inertia-rails.dev",
    icon: BookOpen,
  },
]
</script>

<template>
  <div>
    <div class="border-sidebar-border/80 border-b">
      <div class="mx-auto flex h-16 items-center px-4 md:max-w-7xl">
        <!-- Mobile Menu -->
        <div class="lg:hidden">
          <Sheet>
            <SheetTrigger :as-child="true">
              <Button variant="ghost" size="icon" class="mr-2 h-9 w-9">
                <Menu class="h-5 w-5" />
              </Button>
            </SheetTrigger>
            <SheetContent side="left" class="w-[300px] p-6">
              <SheetTitle class="sr-only">Navigation Menu</SheetTitle>
              <SheetHeader class="flex justify-start text-left">
                <AppLogoIcon
                  class="size-6 fill-current text-black dark:text-white"
                />
              </SheetHeader>
              <div
                class="flex h-full flex-1 flex-col justify-between space-y-4 py-6"
              >
                <nav class="-mx-3 space-y-1">
                  <Link
                    v-for="item in mainNavItems"
                    :key="item.title"
                    :href="item.href"
                    class="hover:bg-accent flex items-center gap-x-3 rounded-lg px-3 py-2 text-sm font-medium"
                    :class="activeItemStyles(item.href)"
                  >
                    <component
                      v-if="item.icon"
                      :is="item.icon"
                      class="h-5 w-5"
                    />
                    {{ item.title }}
                  </Link>
                </nav>
                <div class="flex flex-col space-y-4">
                  <a
                    v-for="item in rightNavItems"
                    :key="item.title"
                    :href="item.href"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="flex items-center space-x-2 text-sm font-medium"
                  >
                    <component
                      v-if="item.icon"
                      :is="item.icon"
                      class="h-5 w-5"
                    />
                    <span>{{ item.title }}</span>
                  </a>
                </div>
              </div>
            </SheetContent>
          </Sheet>
        </div>

        <Link :href="dashboard.index()" class="flex items-center gap-x-2">
          <AppLogo />
        </Link>

        <!-- Desktop Menu -->
        <div class="hidden h-full lg:flex lg:flex-1">
          <NavigationMenu class="ml-10 flex h-full items-stretch">
            <NavigationMenuList class="flex h-full items-stretch space-x-2">
              <NavigationMenuItem
                v-for="(item, index) in mainNavItems"
                :key="index"
                class="relative flex h-full items-center"
              >
                <Link
                  :class="[
                    navigationMenuTriggerStyle(),
                    activeItemStyles(item.href),
                    'h-9 cursor-pointer px-3',
                  ]"
                  :href="item.href"
                >
                  <component
                    v-if="item.icon"
                    :is="item.icon"
                    class="mr-2 h-4 w-4"
                  />
                  {{ item.title }}
                </Link>
                <div
                  v-if="isCurrentRoute(item.href)"
                  class="absolute bottom-0 left-0 h-0.5 w-full translate-y-px bg-black dark:bg-white"
                ></div>
              </NavigationMenuItem>
            </NavigationMenuList>
          </NavigationMenu>
        </div>

        <div class="ml-auto flex items-center space-x-2">
          <div class="relative flex items-center space-x-1">
            <Button
              variant="ghost"
              size="icon"
              class="group h-9 w-9 cursor-pointer"
            >
              <Search class="size-5 opacity-80 group-hover:opacity-100" />
            </Button>

            <div class="hidden space-x-1 lg:flex">
              <template v-for="item in rightNavItems" :key="item.title">
                <TooltipProvider :delay-duration="0">
                  <Tooltip>
                    <TooltipTrigger>
                      <Button
                        variant="ghost"
                        size="icon"
                        as-child
                        class="group h-9 w-9 cursor-pointer"
                      >
                        <a
                          :href="item.href"
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          <span class="sr-only">{{ item.title }}</span>
                          <component
                            :is="item.icon"
                            class="size-5 opacity-80 group-hover:opacity-100"
                          />
                        </a>
                      </Button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p>{{ item.title }}</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </template>
            </div>
          </div>

          <DropdownMenu>
            <DropdownMenuTrigger :as-child="true">
              <Button
                variant="ghost"
                size="icon"
                class="focus-within:ring-primary relative size-10 w-auto rounded-full p-1 focus-within:ring-2"
              >
                <Avatar class="size-8 overflow-hidden rounded-full">
                  <AvatarImage
                    v-if="auth.user.avatar"
                    :src="auth.user.avatar"
                    :alt="auth.user.name"
                  />
                  <AvatarFallback
                    class="rounded-lg bg-neutral-200 font-semibold text-black dark:bg-neutral-700 dark:text-white"
                  >
                    {{ getInitials(auth.user?.name) }}
                  </AvatarFallback>
                </Avatar>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" class="w-56">
              <UserMenuContent :auth="auth" />
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </div>

    <div
      v-if="props.breadcrumbs.length > 1"
      class="border-sidebar-border/70 flex w-full border-b"
    >
      <div
        class="mx-auto flex h-12 w-full items-center justify-start px-4 text-neutral-500 md:max-w-7xl"
      >
        <Breadcrumbs :breadcrumbs="breadcrumbs" />
      </div>
    </div>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/AppLogo.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import AppLogoIcon from "@/components/AppLogoIcon.vue"

const appName = import.meta.env.VITE_APP_NAME ?? "Vue Starter Kit"
</script>

<template>
  <div
    class="bg-sidebar-primary text-sidebar-primary-foreground flex aspect-square size-8 items-center justify-center rounded-md"
  >
    <AppLogoIcon class="size-5 fill-current text-white" />
  </div>
  <div class="ml-1 grid flex-1 text-left text-sm">
    <span class="mb-0.5 truncate leading-tight font-semibold">
      {{ appName }}
    </span>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/AppLogoIcon.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import type { HTMLAttributes } from "vue"

defineOptions({
  inheritAttrs: false,
})

interface Props {
  className?: HTMLAttributes["class"]
}

defineProps<Props>()
</script>

<template>
  <svg
    height="32"
    viewBox="0 0 90 32"
    width="90"
    xmlns="http://www.w3.org/2000/svg"
    :class="className"
    v-bind="$attrs"
  >
    <path
      fill="currentColor"
      d="m418.082357 25.9995403v4.1135034h-7.300339v1.89854h3.684072c1.972509 0 4.072534 1.4664311 4.197997 3.9665124l.005913.2373977v1.5821167c-.087824 3.007959-2.543121 4.1390018-4.071539 4.2011773l-.132371.0027328h-7.390745v-4.0909018l7.481152-.0226016v-1.9889467l-1.190107.0007441-.346911.0008254-.084566.0003251-.127643.0007097-.044785.0003793-.055764.0007949-.016378.0008259c.000518.0004173.013246.0008384.034343.0012518l.052212.000813c.030547.0003979.066903.0007803.105225.0011355l.078131.0006709-.155385-.0004701c-.31438-.001557-.85249-.0041098-1.729029-.0080055-1.775258 0-4.081832-1.3389153-4.219994-3.9549201l-.006518-.24899v-1.423905c0-2.6982402 2.278213-4.182853 4.065464-4.2678491l.161048-.003866zm-18.691579 0v11.8658752h6.170255v4.1361051h-10.735792v-16.0019803zm-6.441475 0v16.0019803h-4.588139v-16.0019803zm-10.803597 0c1.057758 0 4.04923.7305141 4.198142 3.951222l.005768.2526881v11.7980702h-4.271715v-2.8252084h-4.136105v2.8252084h-4.407325v-11.7980702c0-1.3184306 1.004082-4.0468495 3.946899-4.197411l.257011-.0064991zm-24.147177-.0027581 8.580186.0005749c.179372.0196801 4.753355.5702841 4.753355 5.5438436s-3.775694 5.3947112-3.92376 5.4093147l-.004472.0004216 5.00569 5.0505836h-6.374959l-3.726209-3.8608906v3.8608906h-4.309831zm22.418634-2.6971669.033418.0329283s-.384228.27122-.791058.610245c-12.837747-9.4927002-20.680526-5.0175701-23.144107-3.8196818-11.187826 6.2428065-7.954768 21.5678895-7.888988 21.8737669l.001006.0046469h-17.855317s.67805-6.6900935 5.4244-14.600677c4.74635-7.9105834 12.837747-13.9000252 19.414832-14.4876686 12.681632-1.2703535 24.110975 9.7062594 24.805814 10.3864403zm-31.111679 14.1815719 2.44098.881465c.113008.8852319.273103 1.7233771.441046 2.4882761l.101394.4499406-2.7122-.9718717c-.113009-.67805-.226017-1.6499217-.27122-2.84781zm31.506724-7.6619652h-1.514312c-1.128029 0-1.333125.5900716-1.370415.8046431l-.007251.056292-.000906.0152319-.00013 3.9153864h4.136105l-.000316-3.916479c-.004939-.0795522-.08331-.8750744-1.242775-.8750744zm-50.492125.339025 2.599192.94927c-.316423.731729-.719369 1.6711108-1.011998 2.4093289l-.118085.3028712-2.599192-.94927c.226017-.610245.700652-1.7403284 1.130083-2.7122001zm35.445121-.1434449h-3.456844v3.6588673h3.434397s.98767-.3815997.98767-1.8406572-.965223-1.8182101-.965223-1.8182101zm-15.442645-.7606218 1.62732 1.2882951c-.180814.705172-.318232 1.410344-.412255 2.115516l-.06238.528879-1.830735-1.4465067c.180813-.81366.384228-1.6499217.67805-2.4861834zm4.000495-6.3058651 1.017075 1.5369134c-.39779.4158707-.766649.8317413-1.095006 1.2707561l-.238493.3339623-1.08488-1.6273201c.40683-.5198383.881465-1.0396767 1.401304-1.5143117zm-16.182794-3.3450467 1.604719 1.4013034c-.40683.4237812-.800947.8729894-1.172815 1.3285542l-.364099.4569775-1.740328-1.4917101c.519838-.5650416 1.08488-1.1300833 1.672523-1.695125zm22.398252-.0904067.497237 1.4917101c-.524359.162732-1.048717.3688592-1.573076.6068095l-.393269.1842488-.519838-1.559515c.565041-.2486184 1.22049-.4972367 1.988946-.7232534zm5.28879-.54244c.578603.0361627 1.171671.1012555 1.779204.2068505l.458361.0869712-.090406 1.4013034c-.596684-.1265694-1.193368-.2097435-1.790052-.2495224l-.447513-.0216976zm-18.555968-6.2380601 1.017075 1.559515c-.440733.2203663-.868752.4661594-1.303128.7278443l-.437201.2666291-1.039676-1.5821167c.610245-.3616267 1.197888-.67805 1.76293-.9718717zm18.601172-.8588633c1.344799.3842283 1.923513.6474959 2.155025.7707625l.037336.0202958-.090406 1.5143117c-.482169-.1958811-.964338-.381717-1.453204-.5575078l-.739158-.2561522zm-8.633837-1.3334984.452033 1.3787017h-.226016c-.491587 0-.983173.0127134-1.474759.0476754l-.491587.0427313-.429431-1.3334984c.745855-.0904067 1.469108-.13561 2.16976-.13561z"
      transform="translate(-329 -15)"
    />
  </svg>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/AppShell.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { ref, watch } from "vue"

import { SidebarProvider } from "@/components/ui/sidebar"
import * as storage from "@/lib/storage"

interface Props {
  variant?: "header" | "sidebar"
}

defineProps<Props>()

const isOpen = ref(storage.getItem("sidebar") !== "false")

watch(isOpen, (open) => {
  storage.setItem("sidebar", String(open))
})
</script>

<template>
  <div v-if="variant === 'header'" class="flex min-h-screen w-full flex-col">
    <slot />
  </div>
  <SidebarProvider v-else :default-open="isOpen" v-model:open="isOpen">
    <slot />
  </SidebarProvider>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/AppSidebar.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Link } from "@inertiajs/vue3"
import { BookOpen, Folder, LayoutGrid } from "lucide-vue-next"

import NavFooter from "@/components/NavFooter.vue"
import NavMain from "@/components/NavMain.vue"
import NavUser from "@/components/NavUser.vue"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { dashboard } from "@/routes"
import { type NavItem } from "@/types"

import AppLogo from "./AppLogo.vue"

const mainNavItems: NavItem[] = [
  {
    title: "Dashboard",
    href: dashboard.index().url,
    icon: LayoutGrid,
  },
]

const footerNavItems: NavItem[] = [
  {
    title: "Github Repo",
    href: "https://github.com/inertia-rails/vue-starter-kit",
    icon: Folder,
  },
  {
    title: "Documentation",
    href: "https://inertia-rails.dev",
    icon: BookOpen,
  },
]
</script>

<template>
  <Sidebar collapsible="icon" variant="inset">
    <SidebarHeader>
      <SidebarMenu>
        <SidebarMenuItem>
          <SidebarMenuButton size="lg" as-child>
            <Link :href="dashboard.index()">
              <AppLogo />
            </Link>
          </SidebarMenuButton>
        </SidebarMenuItem>
      </SidebarMenu>
    </SidebarHeader>

    <SidebarContent>
      <NavMain :items="mainNavItems" />
    </SidebarContent>

    <SidebarFooter>
      <NavFooter :items="footerNavItems" />
      <NavUser />
    </SidebarFooter>
  </Sidebar>
  <slot />
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/AppSidebarHeader.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import Breadcrumbs from "@/components/Breadcrumbs.vue"
import { SidebarTrigger } from "@/components/ui/sidebar"
import type { BreadcrumbItemType } from "@/types"

withDefaults(
  defineProps<{
    breadcrumbs?: BreadcrumbItemType[]
  }>(),
  {
    breadcrumbs: () => [],
  },
)
</script>

<template>
  <header
    class="border-sidebar-border/70 flex h-16 shrink-0 items-center gap-2 border-b px-6 transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-12 md:px-4"
  >
    <div class="flex items-center gap-2">
      <SidebarTrigger class="-ml-1" />
      <template v-if="breadcrumbs && breadcrumbs.length > 0">
        <Breadcrumbs :breadcrumbs="breadcrumbs" />
      </template>
    </div>
  </header>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/AppearanceTabs.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Monitor, Moon, Sun } from "lucide-vue-next"

import { useAppearance } from "@/composables/useAppearance"

const { appearance, updateAppearance } = useAppearance()

const tabs = [
  { value: "light", Icon: Sun, label: "Light" },
  { value: "dark", Icon: Moon, label: "Dark" },
  { value: "system", Icon: Monitor, label: "System" },
] as const
</script>

<template>
  <div
    class="inline-flex gap-1 rounded-lg bg-neutral-100 p-1 dark:bg-neutral-800"
  >
    <button
      v-for="{ value, Icon, label } in tabs"
      :key="value"
      @click="updateAppearance(value)"
      :class="[
        'flex items-center rounded-md px-3.5 py-1.5 transition-colors',
        appearance === value
          ? 'bg-white shadow-xs dark:bg-neutral-700 dark:text-neutral-100'
          : 'text-neutral-500 hover:bg-neutral-200/60 hover:text-black dark:text-neutral-400 dark:hover:bg-neutral-700/60',
      ]"
    >
      <component :is="Icon" class="-ml-1 h-4 w-4" />
      <span class="ml-1.5 text-sm">{{ label }}</span>
    </button>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/Breadcrumbs.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Link } from "@inertiajs/vue3"

import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb"

interface BreadcrumbItemType {
  title: string
  href?: string
}

defineProps<{
  breadcrumbs: BreadcrumbItemType[]
}>()
</script>

<template>
  <Breadcrumb>
    <BreadcrumbList>
      <template v-for="(item, index) in breadcrumbs" :key="index">
        <BreadcrumbItem>
          <template v-if="index === breadcrumbs.length - 1">
            <BreadcrumbPage>{{ item.title }}</BreadcrumbPage>
          </template>
          <template v-else>
            <BreadcrumbLink as-child>
              <Link :href="item.href ?? '#'">{{ item.title }}</Link>
            </BreadcrumbLink>
          </template>
        </BreadcrumbItem>
        <BreadcrumbSeparator v-if="index !== breadcrumbs.length - 1" />
      </template>
    </BreadcrumbList>
  </Breadcrumb>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/DeleteUser.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Form } from "@inertiajs/vue3"
import { ref } from "vue"

import HeadingSmall from "@/components/HeadingSmall.vue"
import InputError from "@/components/InputError.vue"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { users } from "@/routes"

const passwordInput = ref<HTMLInputElement | null>(null)
</script>

<template>
  <div class="space-y-6">
    <HeadingSmall
      title="Delete account"
      description="Delete your account and all of its resources"
    />
    <div
      class="space-y-4 rounded-lg border border-red-100 bg-red-50 p-4 dark:border-red-200/10 dark:bg-red-700/10"
    >
      <div class="relative space-y-0.5 text-red-600 dark:text-red-100">
        <p class="font-medium">Warning</p>
        <p class="text-sm">
          Please proceed with caution, this cannot be undone.
        </p>
      </div>
      <Dialog>
        <DialogTrigger as-child>
          <Button variant="destructive">Delete account</Button>
        </DialogTrigger>
        <DialogContent>
          <Form
            :action="users.destroy()"
            :options="{ preserveScroll: true }"
            :onError="() => passwordInput?.focus()"
            resetOnSuccess
            className="space-y-6"
            #default="{ resetAndClearErrors, processing, errors }"
          >
            <DialogHeader class="space-y-3">
              <DialogTitle
                >Are you sure you want to delete your account?</DialogTitle
              >
              <DialogDescription>
                Once your account is deleted, all of its resources and data will
                also be permanently deleted. Please enter your password to
                confirm you would like to permanently delete your account.
              </DialogDescription>
            </DialogHeader>

            <div class="grid gap-2">
              <Label for="password_challenge" class="sr-only">Password</Label>
              <Input
                id="password_challenge"
                type="password"
                name="password_challenge"
                ref="passwordInput"
                placeholder="Password"
              />
              <InputError :messages="errors.password_challenge" />
            </div>

            <DialogFooter class="gap-2">
              <DialogClose as-child>
                <Button variant="secondary" @click="resetAndClearErrors">
                  Cancel
                </Button>
              </DialogClose>

              <Button
                type="submit"
                variant="destructive"
                :disabled="processing"
              >
                Delete account
              </Button>
            </DialogFooter>
          </Form>
        </DialogContent>
      </Dialog>
    </div>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/Heading.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
interface Props {
  title: string
  description?: string
}

defineProps<Props>()
</script>

<template>
  <div class="mb-8 space-y-0.5">
    <h2 class="text-xl font-semibold tracking-tight">{{ title }}</h2>
    <p v-if="description" class="text-muted-foreground text-sm">
      {{ description }}
    </p>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/HeadingSmall.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
interface Props {
  title: string
  description?: string
}

defineProps<Props>()
</script>

<template>
  <header>
    <h3 class="mb-0.5 text-base font-medium">{{ title }}</h3>
    <p v-if="description" class="text-muted-foreground text-sm">
      {{ description }}
    </p>
  </header>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/Icon.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import * as icons from "lucide-vue-next"
import { computed } from "vue"

import { cn } from "@/lib/utils"

interface Props {
  name: string
  class?: string
  size?: number | string
  color?: string
  strokeWidth?: number | string
}

const props = withDefaults(defineProps<Props>(), {
  class: "",
  size: 16,
  strokeWidth: 2,
})

const className = computed(() => cn("h-4 w-4", props.class))

const icon = computed(() => {
  const iconName = props.name.charAt(0).toUpperCase() + props.name.slice(1)
  return (icons as Record<string, unknown>)[iconName]
})
</script>

<template>
  <component
    :is="icon"
    :class="className"
    :size="size"
    :stroke-width="strokeWidth"
    :color="color"
  />
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/InputError.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
defineProps<{
  messages?: string[]
}>()
</script>

<template>
  <div v-if="messages">
    <p class="text-sm text-red-600 dark:text-red-500">
      {{ messages.join(", ") }}
    </p>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/NavFooter.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import {
  SidebarGroup,
  SidebarGroupContent,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { type NavItem } from "@/types"

interface Props {
  items: NavItem[]
  class?: string
}

defineProps<Props>()
</script>

<template>
  <SidebarGroup
    :class="`group-data-[collapsible=icon]:p-0 ${$props.class || ''}`"
  >
    <SidebarGroupContent>
      <SidebarMenu>
        <SidebarMenuItem v-for="item in items" :key="item.title">
          <SidebarMenuButton
            class="text-neutral-600 hover:text-neutral-800 dark:text-neutral-300 dark:hover:text-neutral-100"
            as-child
          >
            <a :href="item.href" target="_blank" rel="noopener noreferrer">
              <component :is="item.icon" />
              <span>{{ item.title }}</span>
            </a>
          </SidebarMenuButton>
        </SidebarMenuItem>
      </SidebarMenu>
    </SidebarGroupContent>
  </SidebarGroup>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/NavMain.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Link, usePage } from "@inertiajs/vue3"

import {
  SidebarGroup,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { type NavItem } from "@/types"

defineProps<{
  items: NavItem[]
}>()

const page = usePage()
</script>

<template>
  <SidebarGroup class="px-2 py-0">
    <SidebarGroupLabel>Platform</SidebarGroupLabel>
    <SidebarMenu>
      <SidebarMenuItem v-for="item in items" :key="item.title">
        <SidebarMenuButton
          as-child
          :is-active="item.href === page.url"
          :tooltip="item.title"
        >
          <Link :href="item.href">
            <component :is="item.icon" />
            <span>{{ item.title }}</span>
          </Link>
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  </SidebarGroup>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/NavUser.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { usePage } from "@inertiajs/vue3"
import { ChevronsUpDown } from "lucide-vue-next"

import UserInfo from "@/components/UserInfo.vue"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from "@/components/ui/sidebar"
import { type User } from "@/types"

import UserMenuContent from "./UserMenuContent.vue"

const page = usePage()
const auth = page.props.auth as { user: User; session: { id: number } }
const { isMobile, state } = useSidebar()
</script>

<template>
  <SidebarMenu>
    <SidebarMenuItem>
      <DropdownMenu>
        <DropdownMenuTrigger as-child>
          <SidebarMenuButton
            size="lg"
            class="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
          >
            <UserInfo :user="auth.user" />
            <ChevronsUpDown class="ml-auto size-4" />
          </SidebarMenuButton>
        </DropdownMenuTrigger>
        <DropdownMenuContent
          class="w-(--reka-dropdown-menu-trigger-width) min-w-56 rounded-lg"
          :side="
            isMobile ? 'bottom' : state === 'collapsed' ? 'left' : 'bottom'
          "
          align="end"
          :side-offset="4"
        >
          <UserMenuContent :auth="auth" />
        </DropdownMenuContent>
      </DropdownMenu>
    </SidebarMenuItem>
  </SidebarMenu>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/PlaceholderPattern.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { computed } from "vue"

const patternId = computed(
  () => `pattern-${Math.random().toString(36).substring(2, 9)}`,
)
</script>

<template>
  <svg
    class="absolute inset-0 size-full stroke-neutral-900/20 dark:stroke-neutral-100/20"
    fill="none"
  >
    <defs>
      <pattern
        :id="patternId"
        x="0"
        y="0"
        width="8"
        height="8"
        patternUnits="userSpaceOnUse"
      >
        <path d="M-1 5L5 -1M3 9L8.5 3.5" stroke-width="0.5"></path>
      </pattern>
    </defs>
    <rect
      stroke="none"
      :fill="`url(#${patternId})`"
      width="100%"
      height="100%"
    ></rect>
  </svg>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/ResourceItem.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
interface Props {
  href: string
  text: string
}

defineProps<Props>()
</script>

<template>
  <span
    class="flex h-3.5 w-3.5 items-center justify-center rounded-full border border-[#e3e3e0] bg-[#FDFDFC] shadow-[0px_0px_1px_0px_rgba(0,0,0,0.03),0px_1px_2px_0px_rgba(0,0,0,0.06)] dark:border-[#3E3E3A] dark:bg-[#161615]"
  >
    <span class="h-1.5 w-1.5 rounded-full bg-[#dbdbd7] dark:bg-[#3E3E3A]" />
  </span>
  <a
    :href="href"
    target="_blank"
    class="inline-flex items-center space-x-1 font-medium text-[#f53003] underline underline-offset-4 dark:text-[#FF4433]"
    rel="noreferrer"
  >
    <span>{{ text }}</span>
    <svg width="10" height="11" viewBox="0 0 10 11" class="h-2.5 w-2.5">
      <path
        d="M7.70833 6.95834V2.79167H3.54167M2.5 8L7.5 3.00001"
        stroke="currentColor"
        stroke-linecap="square"
      />
    </svg>
  </a>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/TextLink.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import type { Method } from "@inertiajs/core"
import type { InertiaLinkProps } from "@inertiajs/vue3"
import { Link } from "@inertiajs/vue3"

interface Props {
  href: NonNullable<InertiaLinkProps["href"]>
  tabindex?: number
  method?: Method
  as?: string
}

defineProps<Props>()
</script>

<template>
  <Link
    :href="href"
    :tabindex="tabindex"
    :method="method"
    :as="as"
    class="text-foreground underline decoration-neutral-300 underline-offset-4 transition-colors duration-300 ease-out hover:decoration-current! dark:decoration-neutral-500"
  >
    <slot />
  </Link>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/UserInfo.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { computed } from "vue"

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { useInitials } from "@/composables/useInitials"
import type { User } from "@/types"

interface Props {
  user: User
  showEmail?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  showEmail: false,
})

const { getInitials } = useInitials()

// Compute whether we should show the avatar image
const showAvatar = computed(() => props.user.avatar && props.user.avatar !== "")
</script>

<template>
  <Avatar class="h-8 w-8 overflow-hidden rounded-lg">
    <AvatarImage v-if="showAvatar" :src="user.avatar!" :alt="user.name" />
    <AvatarFallback class="rounded-lg text-black dark:text-white">
      {{ getInitials(user.name) }}
    </AvatarFallback>
  </Avatar>

  <div class="grid flex-1 text-left text-sm leading-tight">
    <span class="truncate font-medium">{{ user.name }}</span>
    <span v-if="showEmail" class="text-muted-foreground truncate text-xs">{{
      user.email
    }}</span>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/UserMenuContent.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Link, router } from "@inertiajs/vue3"
import { LogOut, Settings } from "lucide-vue-next"

import UserInfo from "@/components/UserInfo.vue"
import {
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
} from "@/components/ui/dropdown-menu"
import { sessions, settingsProfiles } from "@/routes"
import type { User } from "@/types"

interface Props {
  auth: {
    session: {
      id: number
    }
    user: User
  }
}

const handleLogout = () => {
  router.flushAll()
}

defineProps<Props>()
</script>

<template>
  <DropdownMenuLabel class="p-0 font-normal">
    <div class="flex items-center gap-2 px-1 py-1.5 text-left text-sm">
      <UserInfo :user="auth.user" :show-email="true" />
    </div>
  </DropdownMenuLabel>
  <DropdownMenuSeparator />
  <DropdownMenuGroup>
    <DropdownMenuItem :as-child="true">
      <Link
        class="block w-full"
        :href="settingsProfiles.show()"
        prefetch
        as="button"
      >
        <Settings class="mr-2 h-4 w-4" />
        Settings
      </Link>
    </DropdownMenuItem>
  </DropdownMenuGroup>
  <DropdownMenuSeparator />
  <DropdownMenuItem :as-child="true">
    <Link
      class="block w-full"
      :href="sessions.destroy(auth.session.id)"
      @click="handleLogout"
      as="button"
    >
      <LogOut class="mr-2 h-4 w-4" />
      Log out
    </Link>
  </DropdownMenuItem>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/composables/useAppearance.ts", ERB.new(
    *[
  <<~'TCODE'
import { onMounted, ref } from "vue"

import { isBrowser } from "@/lib/browser"
import * as storage from "@/lib/storage"

type Appearance = "light" | "dark" | "system"

const prefersDark = () => {
  if (!isBrowser) {
    return false
  }
  return window.matchMedia("(prefers-color-scheme: dark)").matches
}

const applyTheme = (appearance: Appearance) => {
  if (!isBrowser) return

  const isDark =
    appearance === "dark" || (appearance === "system" && prefersDark())

  document.documentElement.classList.toggle("dark", isDark)
}

const mediaQuery = () => {
  if (!isBrowser) {
    return null
  }

  return window.matchMedia("(prefers-color-scheme: dark)")
}

const handleSystemThemeChange = () => {
  const currentAppearance = storage.getItem("appearance") as Appearance
  applyTheme(currentAppearance ?? "system")
}

export function initializeTheme() {
  const savedAppearance =
    (storage.getItem("appearance") as Appearance) || "system"

  applyTheme(savedAppearance)

  mediaQuery()?.addEventListener("change", handleSystemThemeChange)
}

const appearance = ref<Appearance>("system")

export function useAppearance() {
  onMounted(() => {
    const savedAppearance = storage.getItem("appearance") as Appearance | null

    if (savedAppearance) {
      appearance.value = savedAppearance
    }
  })

  function updateAppearance(value: Appearance) {
    appearance.value = value

    if (value === "system") {
      storage.removeItem("appearance")
    } else {
      storage.setItem("appearance", value)
    }
    applyTheme(value)
  }

  return {
    appearance,
    updateAppearance,
  }
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/composables/useFlash.ts", ERB.new(
    *[
  <<~'TCODE'
import { router } from "@inertiajs/vue3"
import { onMounted, onUnmounted } from "vue"
import { toast } from "vue-sonner"

export function useFlash() {
  let removeListener: (() => void) | undefined

  onMounted(() => {
    removeListener = router.on("flash", (event) => {
      const flash = event.detail.flash
      if (flash.alert) {
        toast.error(flash.alert)
      }
      if (flash.notice) {
        toast(flash.notice)
      }
    })
  })

  onUnmounted(() => {
    if (removeListener) {
      removeListener()
    }
  })
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/composables/useInitials.ts", ERB.new(
    *[
  <<~'TCODE'
export function getInitials(fullName?: string): string {
  if (!fullName) return ""

  const names = fullName.trim().split(" ")

  if (names.length === 0) return ""
  if (names.length === 1) return names[0].charAt(0).toUpperCase()

  return `${names[0].charAt(0)}${names[names.length - 1].charAt(0)}`.toUpperCase()
}

export function useInitials() {
  return { getInitials }
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/entrypoints/inertia.ts", ERB.new(
    *[
  <<~'TCODE'
import { createInertiaApp } from "@inertiajs/vue3"

import { initializeTheme } from "@/composables/useAppearance"
import PersistentLayout from "@/layouts/PersistentLayout.vue"

const appName = import.meta.env.VITE_APP_NAME ?? "Vue Starter Kit"

createInertiaApp({
  title: (title) => (title ? `${title} - ${appName}` : appName),
  pages: "../pages",
  layout: () => PersistentLayout,
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: "brackets",
    }),
  },
  progress: {
    color: "#4B5563",
  },
})

// This will set light / dark mode on page load...
initializeTheme()
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/AppLayout.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import AppLayout from "@/layouts/app/AppSidebarLayout.vue"
import type { BreadcrumbItemType } from "@/types"

interface Props {
  breadcrumbs?: BreadcrumbItemType[]
}

withDefaults(defineProps<Props>(), {
  breadcrumbs: () => [],
})
</script>

<template>
  <AppLayout :breadcrumbs="breadcrumbs">
    <slot />
  </AppLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/AuthLayout.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import AuthLayout from "@/layouts/auth/AuthSimpleLayout.vue"

defineProps<{
  title?: string
  description?: string
}>()
</script>

<template>
  <AuthLayout :title="title" :description="description">
    <slot />
  </AuthLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/PersistentLayout.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Toaster } from "@/components/ui/sonner"
import { useFlash } from "@/composables/useFlash"
import "vue-sonner/style.css"

useFlash()
</script>

<template>
  <slot />
  <Toaster richColors position="bottom-right" />
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/app/AppHeaderLayout.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import AppContent from "@/components/AppContent.vue"
import AppHeader from "@/components/AppHeader.vue"
import AppShell from "@/components/AppShell.vue"
import type { BreadcrumbItemType } from "@/types"

interface Props {
  breadcrumbs?: BreadcrumbItemType[]
}

withDefaults(defineProps<Props>(), {
  breadcrumbs: () => [],
})
</script>

<template>
  <AppShell class="flex-col">
    <AppHeader :breadcrumbs="breadcrumbs" />
    <AppContent>
      <slot />
    </AppContent>
  </AppShell>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/app/AppSidebarLayout.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import AppContent from "@/components/AppContent.vue"
import AppShell from "@/components/AppShell.vue"
import AppSidebar from "@/components/AppSidebar.vue"
import AppSidebarHeader from "@/components/AppSidebarHeader.vue"
import type { BreadcrumbItemType } from "@/types"

interface Props {
  breadcrumbs?: BreadcrumbItemType[]
}

withDefaults(defineProps<Props>(), {
  breadcrumbs: () => [],
})
</script>

<template>
  <AppShell variant="sidebar">
    <AppSidebar />
    <AppContent variant="sidebar" class="overflow-x-hidden">
      <AppSidebarHeader :breadcrumbs="breadcrumbs" />
      <slot />
    </AppContent>
  </AppShell>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth/AuthCardLayout.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Link } from "@inertiajs/vue3"

import AppLogoIcon from "@/components/AppLogoIcon.vue"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { home } from "@/routes"

defineProps<{
  title?: string
  description?: string
}>()
</script>

<template>
  <div
    class="bg-muted flex min-h-svh flex-col items-center justify-center gap-6 p-6 md:p-10"
  >
    <div class="flex w-full max-w-md flex-col gap-6">
      <Link
        :href="home.index()"
        class="flex items-center gap-2 self-center font-medium"
      >
        <div class="flex h-9 w-9 items-center justify-center">
          <AppLogoIcon class="size-9 fill-current text-black dark:text-white" />
        </div>
      </Link>

      <div class="flex flex-col gap-6">
        <Card class="rounded-xl">
          <CardHeader class="px-10 pt-8 pb-0 text-center">
            <CardTitle class="text-xl">{{ title }}</CardTitle>
            <CardDescription>
              {{ description }}
            </CardDescription>
          </CardHeader>
          <CardContent class="px-10 py-8">
            <slot />
          </CardContent>
        </Card>
      </div>
    </div>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth/AuthSimpleLayout.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Link } from "@inertiajs/vue3"

import AppLogoIcon from "@/components/AppLogoIcon.vue"
import { home } from "@/routes"

defineProps<{
  title?: string
  description?: string
}>()
</script>

<template>
  <div
    class="bg-background flex min-h-svh flex-col items-center justify-center gap-6 p-6 md:p-10"
  >
    <div class="w-full max-w-sm">
      <div class="flex flex-col gap-8">
        <div class="flex flex-col items-center gap-4">
          <Link
            :href="home.index()"
            class="flex flex-col items-center gap-2 font-medium"
          >
            <div
              class="mb-1 flex size-14 items-center justify-center rounded-md"
            >
              <AppLogoIcon
                class="size-14 fill-current text-[var(--foreground)] dark:text-white"
              />
            </div>
            <span class="sr-only">{{ title }}</span>
          </Link>
          <div class="space-y-2 text-center">
            <h1 class="text-xl font-medium">{{ title }}</h1>
            <p class="text-muted-foreground text-center text-sm">
              {{ description }}
            </p>
          </div>
        </div>
        <slot />
      </div>
    </div>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth/AuthSplitLayout.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Link } from "@inertiajs/vue3"

import AppLogoIcon from "@/components/AppLogoIcon.vue"
import { home } from "@/routes"

defineProps<{
  title?: string
  description?: string
}>()

const appName = import.meta.env.VITE_APP_NAME ?? "Vue Starter Kit"
</script>

<template>
  <div
    class="relative grid h-dvh flex-col items-center justify-center px-8 sm:px-0 lg:max-w-none lg:grid-cols-2 lg:px-0"
  >
    <div
      class="bg-muted relative hidden h-full flex-col p-10 text-white lg:flex dark:border-r"
    >
      <div class="absolute inset-0 bg-zinc-900" />
      <Link
        :href="home.index()"
        class="relative z-20 flex items-center text-lg font-medium"
      >
        <AppLogoIcon class="mr-2 size-8 fill-current text-white" />
        {{ appName }}
      </Link>
      <div class="relative z-20 mt-auto">
        <blockquote class="space-y-2">
          <p class="text-lg">
            &ldquo;The One Person Framework. A toolkit so powerful that it
            allows a single individual to create modern applications upon which
            they might build a competitive business.&rdquo;
          </p>
          <footer class="text-sm text-neutral-300">DHH</footer>
        </blockquote>
      </div>
    </div>
    <div class="lg:p-8">
      <div
        class="mx-auto flex w-full flex-col justify-center space-y-6 sm:w-[350px]"
      >
        <div class="flex flex-col space-y-2 text-center">
          <h1 class="text-xl font-medium tracking-tight" v-if="title">
            {{ title }}
          </h1>
          <p class="text-muted-foreground text-sm" v-if="description">
            {{ description }}
          </p>
        </div>
        <slot />
      </div>
    </div>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/settings/Layout.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Link, usePage } from "@inertiajs/vue3"

import Heading from "@/components/Heading.vue"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import {
  settingsAppearance,
  settingsEmails,
  settingsPasswords,
  settingsProfiles,
  settingsSessions,
} from "@/routes"
import { type NavItem } from "@/types"

const sidebarNavItems: NavItem[] = [
  {
    title: "Profile",
    href: settingsProfiles.show().url,
  },
  {
    title: "Email",
    href: settingsEmails.show().url,
  },
  {
    title: "Password",
    href: settingsPasswords.show().url,
  },
  {
    title: "Sessions",
    href: settingsSessions.index().url,
  },
  {
    title: "Appearance",
    href: settingsAppearance().url,
  },
]

const page = usePage()
</script>

<template>
  <div class="px-4 py-6">
    <Heading
      title="Settings"
      description="Manage your profile and account settings"
    />

    <div class="flex flex-col lg:flex-row lg:space-x-12">
      <aside class="w-full max-w-xl lg:w-48">
        <nav class="flex flex-col space-y-1 space-x-0">
          <Button
            v-for="item in sidebarNavItems"
            :key="item.href"
            variant="ghost"
            :class="[
              'w-full justify-start',
              { 'bg-muted': page.url === item.href },
            ]"
            as-child
          >
            <Link :href="item.href">
              {{ item.title }}
            </Link>
          </Button>
        </nav>
      </aside>

      <Separator class="my-6 lg:hidden" />

      <div class="flex-1 md:max-w-2xl">
        <section class="max-w-xl space-y-12">
          <slot />
        </section>
      </div>
    </div>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/lib/utils.ts", ERB.new(
    *[
  <<~'TCODE'
import type { ClassValue } from "clsx"
import { clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/dashboard/index.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Head } from "@inertiajs/vue3"

import AppLayout from "@/layouts/AppLayout.vue"
import { dashboard } from "@/routes"
import { type BreadcrumbItem } from "@/types"

import PlaceholderPattern from "../../components/PlaceholderPattern.vue"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Dashboard",
    href: dashboard.index().url,
  },
]
</script>

<template>
  <Head :title="breadcrumbs[breadcrumbs.length - 1].title" />

  <AppLayout :breadcrumbs="breadcrumbs">
    <div
      class="flex h-full flex-1 flex-col gap-4 overflow-x-auto rounded-xl p-4"
    >
      <div class="grid auto-rows-min gap-4 md:grid-cols-3">
        <div
          class="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border"
        >
          <PlaceholderPattern />
        </div>
        <div
          class="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border"
        >
          <PlaceholderPattern />
        </div>
        <div
          class="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border"
        >
          <PlaceholderPattern />
        </div>
      </div>
      <div
        class="border-sidebar-border/70 dark:border-sidebar-border relative min-h-[100vh] flex-1 rounded-xl border md:min-h-min"
      >
        <PlaceholderPattern />
      </div>
    </div>
  </AppLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/home/index.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Head, Link } from "@inertiajs/vue3"

import AppLogoIcon from "@/components/AppLogoIcon.vue"
import ResourceItem from "@/components/ResourceItem.vue"
import { dashboard, sessions, users } from "@/routes"

const appName = import.meta.env.VITE_APP_NAME ?? "Vue Starter Kit"

const links = [
  [
    {
      text: "Inertia Rails Docs",
      href: "https://inertia-rails.dev",
    },
    {
      text: "shadcn/vue Components",
      href: "https://shadcn-vue.com",
    },
    {
      text: "React Docs",
      href: "https://react.dev",
    },
    {
      text: "Rails Guides",
      href: "https://guides.rubyonrails.org",
    },
  ],
]
</script>

<template>
  <Head title="Welcome">
    <link rel="preconnect" href="https://rsms.me/" />
    <link rel="stylesheet" href="https://rsms.me/inter/inter.css" />
  </Head>
  <div
    class="flex min-h-screen flex-col items-center bg-[#FDFDFC] p-6 text-[#1b1b18] lg:justify-center lg:p-8 dark:bg-[#0a0a0a]"
  >
    <header
      class="mb-6 w-full max-w-[335px] text-sm not-has-[nav]:hidden lg:max-w-4xl"
    >
      <nav class="flex items-center justify-end gap-4">
        <Link
          v-if="$page.props.auth.user"
          :href="dashboard.index()"
          class="inline-block rounded-sm border border-[#19140035] px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#1915014a] dark:border-[#3E3E3A] dark:text-[#EDEDEC] dark:hover:border-[#62605b]"
        >
          Dashboard
        </Link>
        <template v-else>
          <Link
            :href="sessions.new()"
            class="inline-block rounded-sm border border-transparent px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#19140035] dark:text-[#EDEDEC] dark:hover:border-[#3E3E3A]"
          >
            Log in
          </Link>
          <Link
            :href="users.new()"
            class="inline-block rounded-sm border border-[#19140035] px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#1915014a] dark:border-[#3E3E3A] dark:text-[#EDEDEC] dark:hover:border-[#62605b]"
          >
            Register
          </Link>
        </template>
      </nav>
    </header>
    <div
      class="flex w-full items-center justify-center opacity-100 transition-opacity duration-750 lg:grow starting:opacity-0"
    >
      <main
        class="flex w-full max-w-[335px] flex-col-reverse overflow-hidden rounded-lg lg:max-w-4xl lg:flex-row"
      >
        <div
          class="flex-1 rounded-br-lg rounded-bl-lg bg-white p-6 pb-12 text-[13px] leading-[20px] shadow-[inset_0px_0px_0px_1px_rgba(26,26,0,0.16)] lg:rounded-tl-lg lg:rounded-br-none lg:p-20 dark:bg-[#161615] dark:text-[#EDEDEC] dark:shadow-[inset_0px_0px_0px_1px_#fffaed2d]"
        >
          <h1 class="mb-1 font-medium">
            {{ appName }}
          </h1>
          <p class="mb-2 text-[#706f6c] dark:text-[#A1A09A]">
            Rails + Inertia.js + Vue.js + shadcn/vue
            <br />
            Here are some resources to begin:
          </p>

          <ul class="mb-4 flex flex-col lg:mb-6">
            <li
              v-for="(link, index) in links[0]"
              :key="index"
              class="relative flex items-center gap-4 py-2"
            >
              <ResourceItem :text="link.text" :href="link.href" />
            </li>
          </ul>
          <ul class="flex gap-3 text-sm leading-normal">
            <li>
              <a
                href="https://inertia-rails.dev/"
                target="_blank"
                class="inline-block rounded-sm border border-black bg-[#1b1b18] px-5 py-1.5 text-sm leading-normal text-white hover:border-black hover:bg-black dark:border-[#eeeeec] dark:bg-[#eeeeec] dark:text-[#1C1C1A] dark:hover:border-white dark:hover:bg-white"
              >
                Learn more
              </a>
            </li>
          </ul>
        </div>

        <div
          class="relative -mb-px aspect-[335/376] w-full shrink-0 overflow-hidden rounded-t-lg bg-[#D30001] p-10 text-white lg:mb-0 lg:-ml-px lg:aspect-auto lg:w-[438px] lg:rounded-t-none lg:rounded-r-lg"
        >
          <AppLogoIcon class="h-full w-full" />
        </div>
      </main>
    </div>
  </div>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/identity/password_resets/edit.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Form, Head } from "@inertiajs/vue3"
import { LoaderCircle } from "lucide-vue-next"

import InputError from "@/components/InputError.vue"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AuthLayout from "@/layouts/AuthLayout.vue"
import { identityPasswordResets } from "@/routes"

interface Props {
  sid: string
  email: string
}

const props = defineProps<Props>()
</script>

<template>
  <AuthLayout
    title="Reset password"
    description="Please enter your new password below"
  >
    <Head title="Reset password" />

    <Form
      :action="identityPasswordResets.update()"
      :transform="(data) => ({ ...data, sid, email })"
      :resetOnSuccess="['password', 'password_confirmation']"
      #default="{ errors, processing }"
    >
      <div class="grid gap-6">
        <div class="grid gap-2">
          <Label for="email">Email</Label>
          <Input
            id="email"
            name="email"
            type="email"
            autocomplete="email"
            :defaultValue="props.email"
            class="mt-1 block w-full"
            readonly
          />
          <InputError :messages="errors.email" class="mt-2" />
        </div>

        <div class="grid gap-2">
          <Label for="password">Password</Label>
          <Input
            id="password"
            name="password"
            type="password"
            autocomplete="new-password"
            class="mt-1 block w-full"
            autofocus
            placeholder="Password"
          />
          <InputError :messages="errors.password" />
        </div>

        <div class="grid gap-2">
          <Label for="password_confirmation"> Confirm Password </Label>
          <Input
            id="password_confirmation"
            name="password_confirmation"
            type="password"
            autocomplete="new-password"
            class="mt-1 block w-full"
            placeholder="Confirm password"
          />
          <InputError :messages="errors.password_confirmation" />
        </div>

        <Button type="submit" class="mt-4 w-full" :disabled="processing">
          <LoaderCircle v-if="processing" class="h-4 w-4 animate-spin" />
          Reset password
        </Button>
      </div>
    </Form>
  </AuthLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/identity/password_resets/new.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Form, Head } from "@inertiajs/vue3"
import { LoaderCircle } from "lucide-vue-next"

import InputError from "@/components/InputError.vue"
import TextLink from "@/components/TextLink.vue"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AuthLayout from "@/layouts/AuthLayout.vue"
import { identityPasswordResets, sessions } from "@/routes"
</script>

<template>
  <AuthLayout
    title="Forgot password"
    description="Enter your email to receive a password reset link"
  >
    <Head title="Forgot password" />

    <div class="space-y-6">
      <Form
        :action="identityPasswordResets.create()"
        #default="{ errors, processing }"
      >
        <div class="grid gap-2">
          <Label for="email">Email address</Label>
          <Input
            id="email"
            name="email"
            type="email"
            autocomplete="off"
            autofocus
            placeholder="email@example.com"
          />
          <InputError :messages="errors.email" />
        </div>

        <div class="my-6 flex items-center justify-start">
          <Button class="w-full" :disabled="processing">
            <LoaderCircle v-if="processing" class="h-4 w-4 animate-spin" />
            Email password reset link
          </Button>
        </div>
      </Form>

      <div class="text-muted-foreground space-x-1 text-center text-sm">
        <span>Or, return to</span>
        <TextLink :href="sessions.new()">log in</TextLink>
      </div>
    </div>
  </AuthLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/sessions/new.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Form, Head } from "@inertiajs/vue3"
import { LoaderCircle } from "lucide-vue-next"

import InputError from "@/components/InputError.vue"
import TextLink from "@/components/TextLink.vue"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AuthBase from "@/layouts/AuthLayout.vue"
import { identityPasswordResets, sessions, users } from "@/routes"
</script>

<template>
  <AuthBase
    title="Log in to your account"
    description="Enter your email and password below to log in"
  >
    <Head title="Log in" />

    <Form
      :action="sessions.create()"
      :resetOnSuccess="['password']"
      class="flex flex-col gap-6"
      #default="{ errors, processing }"
    >
      <div class="grid gap-6">
        <div class="grid gap-2">
          <Label for="email">Email address</Label>
          <Input
            id="email"
            name="email"
            type="email"
            required
            autofocus
            :tabindex="1"
            autocomplete="email"
            placeholder="email@example.com"
          />
          <InputError :messages="errors.email" />
        </div>

        <div class="grid gap-2">
          <div class="flex items-center justify-between">
            <Label for="password">Password</Label>
            <TextLink
              :href="identityPasswordResets.new()"
              class="text-sm"
              :tabindex="5"
            >
              Forgot password?
            </TextLink>
          </div>
          <Input
            id="password"
            name="password"
            type="password"
            required
            :tabindex="2"
            autocomplete="current-password"
            placeholder="Password"
          />
          <InputError :messages="errors.password" />
        </div>

        <Button
          type="submit"
          class="mt-4 w-full"
          :tabindex="4"
          :disabled="processing"
        >
          <LoaderCircle v-if="processing" class="h-4 w-4 animate-spin" />
          Log in
        </Button>
      </div>

      <div class="text-muted-foreground text-center text-sm">
        Don't have an account?
        <TextLink :href="users.new()" :tabindex="5">Sign up</TextLink>
      </div>
    </Form>
  </AuthBase>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/appearance.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Head } from "@inertiajs/vue3"

import AppearanceTabs from "@/components/AppearanceTabs.vue"
import HeadingSmall from "@/components/HeadingSmall.vue"
import AppLayout from "@/layouts/AppLayout.vue"
import SettingsLayout from "@/layouts/settings/Layout.vue"
import { settingsAppearance } from "@/routes"
import { type BreadcrumbItem } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Appearance settings",
    href: settingsAppearance().url,
  },
]
</script>

<template>
  <AppLayout :breadcrumbs="breadcrumbs">
    <Head :title="breadcrumbs[breadcrumbs.length - 1].title" />

    <SettingsLayout>
      <div class="space-y-6">
        <HeadingSmall
          title="Appearance settings"
          description="Update your account's appearance settings"
        />
        <AppearanceTabs />
      </div>
    </SettingsLayout>
  </AppLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/emails/show.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Form, Head, Link, usePage } from "@inertiajs/vue3"

import HeadingSmall from "@/components/HeadingSmall.vue"
import InputError from "@/components/InputError.vue"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AppLayout from "@/layouts/AppLayout.vue"
import SettingsLayout from "@/layouts/settings/Layout.vue"
import { identityEmailVerifications, settingsEmails } from "@/routes"
import type { BreadcrumbItem, User } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Email settings",
    href: settingsEmails.show().url,
  },
]

const page = usePage()
const user = page.props.auth.user as User
</script>

<template>
  <AppLayout :breadcrumbs="breadcrumbs">
    <Head :title="breadcrumbs[breadcrumbs.length - 1].title" />

    <SettingsLayout>
      <div class="space-y-6">
        <HeadingSmall
          title="Update email"
          description="Update your email address and verify it"
        />

        <Form
          :action="settingsEmails.update()"
          :options="{ preserveScroll: true }"
          :resetOnError="['password_challenge']"
          :resetOnSuccess="['password_challenge']"
          class="space-y-6"
          #default="{ errors, processing, recentlySuccessful }"
        >
          <div class="grid gap-2">
            <Label for="email">Email address</Label>

            <Input
              id="email"
              name="email"
              type="email"
              class="mt-1 block w-full"
              :defaultValue="user.email"
              required
              autocomplete="username"
              placeholder="Email address"
            />

            <InputError class="mt-2" :messages="errors.email" />
          </div>

          <div v-if="!user.verified">
            <p class="text-muted-foreground -mt-4 text-sm">
              Your email address is unverified.
              <Link
                :href="identityEmailVerifications.create()"
                as="button"
                class="text-foreground underline decoration-neutral-300 underline-offset-4 transition-colors duration-300 ease-out hover:decoration-current! dark:decoration-neutral-500"
              >
                Click here to resend the verification email.
              </Link>
            </p>
          </div>

          <div class="grid gap-2">
            <Label for="password_challenge">Current password</Label>

            <Input
              id="password_challenge"
              name="password_challenge"
              ref="currentPasswordInput"
              type="password"
              class="mt-1 block w-full"
              autocomplete="current-password"
              placeholder="Current password"
            />

            <InputError :messages="errors.password_challenge" />
          </div>

          <div class="flex items-center gap-4">
            <Button :disabled="processing">Save</Button>

            <Transition
              enter-active-class="transition ease-in-out"
              enter-from-class="opacity-0"
              leave-active-class="transition ease-in-out"
              leave-to-class="opacity-0"
            >
              <p v-show="recentlySuccessful" class="text-sm text-neutral-600">
                Saved
              </p>
            </Transition>
          </div>
        </Form>
      </div>
    </SettingsLayout>
  </AppLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/passwords/show.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Form, Head } from "@inertiajs/vue3"

import HeadingSmall from "@/components/HeadingSmall.vue"
import InputError from "@/components/InputError.vue"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AppLayout from "@/layouts/AppLayout.vue"
import SettingsLayout from "@/layouts/settings/Layout.vue"
import { settingsPasswords } from "@/routes"
import { type BreadcrumbItem } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Password settings",
    href: settingsPasswords.show().url,
  },
]
</script>

<template>
  <AppLayout :breadcrumbs="breadcrumbs">
    <Head :title="breadcrumbs[breadcrumbs.length - 1].title" />

    <SettingsLayout>
      <div class="space-y-6">
        <HeadingSmall
          title="Update password"
          description="Ensure your account is using a long, random password to stay secure"
        />

        <Form
          class="space-y-6"
          :action="settingsPasswords.update()"
          :options="{ preserveScroll: true }"
          resetOnError
          resetOnSuccess
          #default="{ errors, processing, recentlySuccessful }"
        >
          <div class="grid gap-2">
            <Label for="password_challenge">Current password</Label>
            <Input
              id="password_challenge"
              name="password_challenge"
              type="password"
              class="mt-1 block w-full"
              autocomplete="current-password"
              placeholder="Current password"
            />
            <InputError :messages="errors.password_challenge" />
          </div>

          <div class="grid gap-2">
            <Label for="password">New password</Label>
            <Input
              id="password"
              name="password"
              type="password"
              class="mt-1 block w-full"
              autocomplete="new-password"
              placeholder="New password"
            />
            <InputError :messages="errors.password" />
          </div>

          <div class="grid gap-2">
            <Label for="password_confirmation">Confirm password</Label>
            <Input
              id="password_confirmation"
              name="password_confirmation"
              type="password"
              class="mt-1 block w-full"
              autocomplete="new-password"
              placeholder="Confirm password"
            />
            <InputError :messages="errors.password_confirmation" />
          </div>

          <div class="flex items-center gap-4">
            <Button :disabled="processing">Save password</Button>

            <Transition
              enter-active-class="transition ease-in-out"
              enter-from-class="opacity-0"
              leave-active-class="transition ease-in-out"
              leave-to-class="opacity-0"
            >
              <p v-show="recentlySuccessful" class="text-sm text-neutral-600">
                Saved.
              </p>
            </Transition>
          </div>
        </Form>
      </div>
    </SettingsLayout>
  </AppLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/profiles/show.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Form, Head, usePage } from "@inertiajs/vue3"

import DeleteUser from "@/components/DeleteUser.vue"
import HeadingSmall from "@/components/HeadingSmall.vue"
import InputError from "@/components/InputError.vue"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AppLayout from "@/layouts/AppLayout.vue"
import SettingsLayout from "@/layouts/settings/Layout.vue"
import { settingsProfiles } from "@/routes"
import { type BreadcrumbItem, type User } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Profile settings",
    href: settingsProfiles.show().url,
  },
]

const page = usePage()
const user = page.props.auth.user as User
</script>

<template>
  <AppLayout :breadcrumbs="breadcrumbs">
    <Head :title="breadcrumbs[breadcrumbs.length - 1].title" />

    <SettingsLayout>
      <div class="flex flex-col space-y-6">
        <HeadingSmall
          title="Profile information"
          description="Update your name and email address"
        />

        <Form
          :action="settingsProfiles.update()"
          :options="{ preserveScroll: true }"
          class="space-y-6"
          #default="{ errors, processing, recentlySuccessful }"
        >
          <div class="grid gap-2">
            <Label for="name">Name</Label>
            <Input
              id="name"
              name="name"
              :defaultValue="user.name"
              class="mt-1 block w-full"
              required
              autocomplete="name"
              placeholder="Full name"
            />
            <InputError class="mt-2" :messages="errors.name" />
          </div>

          <div class="flex items-center gap-4">
            <Button :disabled="processing">Save</Button>

            <Transition
              enter-active-class="transition ease-in-out"
              enter-from-class="opacity-0"
              leave-active-class="transition ease-in-out"
              leave-to-class="opacity-0"
            >
              <p v-show="recentlySuccessful" class="text-sm text-neutral-600">
                Saved.
              </p>
            </Transition>
          </div>
        </Form>
      </div>

      <DeleteUser />
    </SettingsLayout>
  </AppLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/sessions/index.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Head, Link, usePage } from "@inertiajs/vue3"

import HeadingSmall from "@/components/HeadingSmall.vue"
import { Button } from "@/components/ui/button"
import AppLayout from "@/layouts/AppLayout.vue"
import SettingsLayout from "@/layouts/settings/Layout.vue"
import { sessions as sessionsRoutes, settingsSessions } from "@/routes"
import type { BreadcrumbItem, Session } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Sessions",
    href: settingsSessions.index().url,
  },
]

interface Props {
  sessions: Session[]
}

defineProps<Props>()

const { auth } = usePage().props
</script>

<template>
  <AppLayout :breadcrumbs="breadcrumbs">
    <Head :title="breadcrumbs[breadcrumbs.length - 1].title" />

    <SettingsLayout>
      <div class="space-y-6">
        <HeadingSmall
          title="Sessions"
          description="Manage your active sessions across devices"
        />
        <div class="space-y-4">
          <div
            v-for="session in sessions"
            :key="session.id"
            class="flex flex-col space-y-2 rounded-lg border p-4"
          >
            <div class="flex items-center justify-between">
              <div class="space-y-1">
                <p class="font-medium">
                  {{ session.user_agent }}
                  <Badge
                    v-if="session.id === auth.session.id"
                    variant="secondary"
                    class="ml-2"
                  >
                    Current
                  </Badge>
                </p>
                <p class="text-muted-foreground text-sm">
                  IP: {{ session.ip_address }}
                </p>
                <p class="text-muted-foreground text-sm">
                  Active since:
                  {{ new Date(session.created_at).toLocaleString() }}
                </p>
              </div>
              <Button
                v-if="session.id !== auth.session.id"
                variant="destructive"
                asChild
              >
                <Link
                  :href="sessionsRoutes.destroy(session.id)"
                  as="button"
                >
                  Log out
                </Link>
              </Button>
            </div>
          </div>
        </div>
      </div>
    </SettingsLayout>
  </AppLayout>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/users/new.vue", ERB.new(
    *[
  <<~'TCODE'
<script setup lang="ts">
import { Form, Head } from "@inertiajs/vue3"
import { LoaderCircle } from "lucide-vue-next"

import InputError from "@/components/InputError.vue"
import TextLink from "@/components/TextLink.vue"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import AuthBase from "@/layouts/AuthLayout.vue"
import { sessions, users } from "@/routes"
</script>

<template>
  <AuthBase
    title="Create an account"
    description="Enter your details below to create your account"
  >
    <Head title="Register" />

    <Form
      :action="users.create()"
      :resetOnSuccess="['password', 'password_confirmation']"
      disableWhileProcessing
      class="flex flex-col gap-6"
      #default="{ errors, processing }"
    >
      <div class="grid gap-6">
        <div class="grid gap-2">
          <Label for="name">Name</Label>
          <Input
            id="name"
            name="name"
            type="text"
            required
            autofocus
            :tabindex="1"
            autocomplete="name"
            placeholder="Full name"
          />
          <InputError :messages="errors.name" />
        </div>

        <div class="grid gap-2">
          <Label for="email">Email address</Label>
          <Input
            id="email"
            name="email"
            type="email"
            required
            :tabindex="2"
            autocomplete="email"
            placeholder="email@example.com"
          />
          <InputError :messages="errors.email" />
        </div>

        <div class="grid gap-2">
          <Label for="password">Password</Label>
          <Input
            id="password"
            name="password"
            type="password"
            required
            :tabindex="3"
            autocomplete="new-password"
            placeholder="Password"
          />
          <InputError :messages="errors.password" />
        </div>

        <div class="grid gap-2">
          <Label for="password_confirmation">Confirm password</Label>
          <Input
            id="password_confirmation"
            name="password_confirmation"
            type="password"
            required
            :tabindex="4"
            autocomplete="new-password"
            placeholder="Confirm password"
          />
          <InputError :messages="errors.password_confirmation" />
        </div>

        <Button
          type="submit"
          class="mt-2 w-full"
          :tabindex="5"
          :disabled="processing"
        >
          <LoaderCircle v-if="processing" class="h-4 w-4 animate-spin" />
          Create account
        </Button>
      </div>

      <div class="text-muted-foreground text-center text-sm">
        Already have an account?
        <TextLink
          :href="sessions.new()"
          class="underline underline-offset-4"
          :tabindex="6"
          >Log in</TextLink
        >
      </div>
    </Form>
  </AuthBase>
</template>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/types/index.ts", ERB.new(
    *[
  <<~'TCODE'
import type { LucideIcon } from "lucide-vue-next"

export interface Auth {
  user: User
  session: Pick<Session, "id">
}

export interface BreadcrumbItem {
  title: string
  href: string
}

export interface NavItem {
  title: string
  href: string
  icon?: LucideIcon
  isActive?: boolean
}

export interface FlashData {
  alert?: string
  notice?: string
}

export interface SharedProps {
  auth: Auth
}

export interface User {
  id: number
  name: string
  email: string
  avatar?: string
  verified: boolean
  created_at: string
  updated_at: string
}

export type BreadcrumbItemType = BreadcrumbItem

export interface Session {
  id: number
  user_agent: string
  ip_address: string
  created_at: string
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true  when "svelte"
    file "#{js_destination_path}/components/app-content.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { Snippet } from "svelte"

  import { SidebarInset } from "@/components/ui/sidebar"

  interface Props {
    variant?: "header" | "sidebar"
    class?: string
    children?: Snippet
  }

  let { variant, class: className, children }: Props = $props()
</script>

{#if variant === "sidebar"}
  <SidebarInset class={className}>
    {@render children?.()}
  </SidebarInset>
{:else}
  <main
    class="mx-auto flex h-full w-full max-w-7xl flex-1 flex-col gap-4 rounded-xl {className ||
      ''}"
  >
    {@render children?.()}
  </main>
{/if}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-header.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { inertia, Link, page } from "@inertiajs/svelte"
  import { BookOpen, Folder, LayoutGrid, Menu, Search } from "@lucide/svelte"

  import AppLogoIcon from "@/components/app-logo-icon.svelte"
  import AppLogo from "@/components/app-logo.svelte"
  import Breadcrumbs from "@/components/breadcrumbs.svelte"
  import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
  import { Button } from "@/components/ui/button"
  import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuTrigger,
  } from "@/components/ui/dropdown-menu"
  import * as NavigationMenu from "@/components/ui/navigation-menu"
  import { navigationMenuTriggerStyle } from "@/components/ui/navigation-menu/navigation-menu-trigger.svelte"
  import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
    SheetTrigger,
  } from "@/components/ui/sheet"
  import {
    Tooltip,
    TooltipContent,
    TooltipProvider,
    TooltipTrigger,
  } from "@/components/ui/tooltip"
  import UserMenuContent from "@/components/user-menu-content.svelte"
  import { dashboard } from "@/routes"
  import { getInitials } from "@/runes/use-initials"
  import type { BreadcrumbItem, NavItem } from "@/types"

  interface Props {
    breadcrumbs?: BreadcrumbItem[]
  }

  let { breadcrumbs = [] }: Props = $props()

  const auth = $derived(page.props.auth)

  const isCurrentRoute = $derived((url: string) => page.url === url)

  const activeItemStyles = $derived((url: string) =>
    isCurrentRoute(url)
      ? "text-neutral-900 dark:bg-neutral-800 dark:text-neutral-100"
      : "",
  )

  const mainNavItems: NavItem[] = [
    {
      title: "Dashboard",
      href: "/dashboard",
      icon: LayoutGrid,
    },
  ]

  const rightNavItems: NavItem[] = [
    {
      title: "Repository",
      href: "https://github.com/inertia-rails/svelte-starter-kit",
      icon: Folder,
    },
    {
      title: "Documentation",
      href: "https://inertia-rails.dev",
      icon: BookOpen,
    },
  ]
</script>

<div>
  <div class="border-sidebar-border/80 border-b">
    <div class="mx-auto flex h-16 items-center px-4 md:max-w-7xl">
      <!-- Mobile Menu -->
      <div class="lg:hidden">
        <Sheet>
          <SheetTrigger>
            <Button variant="ghost" size="icon" class="mr-2 h-9 w-9">
              <Menu class="h-5 w-5" />
            </Button>
          </SheetTrigger>
          <SheetContent side="left" class="w-[300px] p-6">
            <SheetTitle class="sr-only">Navigation Menu</SheetTitle>
            <SheetHeader class="flex justify-start text-left">
              <AppLogoIcon
                class="size-6 fill-current text-black dark:text-white"
              />
            </SheetHeader>
            <div
              class="flex h-full flex-1 flex-col justify-between space-y-4 py-6"
            >
              <nav class="-mx-3 space-y-1">
                {#each mainNavItems as item (item.title)}
                  <a
                    href={item.href}
                    use:inertia
                    class="hover:bg-accent flex items-center gap-x-3 rounded-lg px-3 py-2 text-sm font-medium {activeItemStyles(
                      item.href,
                    )}"
                  >
                    {#if item.icon}
                      <item.icon class="h-5 w-5" />
                    {/if}
                    {item.title}
                  </a>
                {/each}
              </nav>
              <div class="flex flex-col space-y-4">
                {#each rightNavItems as item (item.title)}
                  <a
                    href={item.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="flex items-center space-x-2 text-sm font-medium"
                  >
                    {#if item.icon}
                      <item.icon class="h-5 w-5" />
                    {/if}
                    <span>{item.title}</span>
                  </a>
                {/each}
              </div>
            </div>
          </SheetContent>
        </Sheet>
      </div>

      <Link href={dashboard.index()} class="flex items-center gap-x-2">
        <AppLogo />
      </Link>

      <!-- Desktop Menu -->
      <div class="hidden h-full lg:flex lg:flex-1">
        <NavigationMenu.Root class="ml-10 flex h-full items-stretch">
          <NavigationMenu.List class="flex h-full items-stretch space-x-2">
            {#each mainNavItems as item, index (index)}
              <NavigationMenu.Item class="relative flex h-full items-center">
                <a
                  class="{navigationMenuTriggerStyle()} {activeItemStyles(
                    item.href,
                  )} h-9 cursor-pointer px-3"
                  href={item.href}
                  use:inertia
                >
                  {#if item.icon}
                    <item.icon class="mr-2 h-4 w-4" />
                  {/if}
                  {item.title}
                </a>
                {#if isCurrentRoute(item.href)}
                  <div
                    class="absolute bottom-0 left-0 h-0.5 w-full translate-y-px bg-black dark:bg-white"
                  ></div>
                {/if}
              </NavigationMenu.Item>
            {/each}
          </NavigationMenu.List>
        </NavigationMenu.Root>
      </div>

      <div class="ml-auto flex items-center space-x-2">
        <div class="relative flex items-center space-x-1">
          <Button
            variant="ghost"
            size="icon"
            class="group h-9 w-9 cursor-pointer"
          >
            <Search class="size-5 opacity-80 group-hover:opacity-100" />
          </Button>

          <div class="hidden space-x-1 lg:flex">
            {#each rightNavItems as item (item.title)}
              <TooltipProvider delayDuration={0}>
                <Tooltip>
                  <TooltipTrigger>
                    <Button
                      variant="ghost"
                      size="icon"
                      class="group h-9 w-9 cursor-pointer"
                      href={item.href}
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      <span class="sr-only">{item.title}</span>
                      <item.icon
                        class="size-5 opacity-80 group-hover:opacity-100"
                      />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>
                    <p>{item.title}</p>
                  </TooltipContent>
                </Tooltip>
              </TooltipProvider>
            {/each}
          </div>
        </div>

        <DropdownMenu>
          <DropdownMenuTrigger>
            <Button
              variant="ghost"
              size="icon"
              class="focus-within:ring-primary relative size-10 w-auto rounded-full p-1 focus-within:ring-2"
            >
              <Avatar class="size-8 overflow-hidden rounded-full">
                {#if auth.user.avatar}
                  <AvatarImage src={auth.user.avatar} alt={auth.user.name} />
                {/if}
                <AvatarFallback
                  class="rounded-lg bg-neutral-200 font-semibold text-black dark:bg-neutral-700 dark:text-white"
                >
                  {getInitials(auth.user?.name)}
                </AvatarFallback>
              </Avatar>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" class="w-56">
            <UserMenuContent {auth} />
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </div>
  </div>

  {#if breadcrumbs.length > 1}
    <div class="border-sidebar-border/70 flex w-full border-b">
      <div
        class="mx-auto flex h-12 w-full items-center justify-start px-4 text-neutral-500 md:max-w-7xl"
      >
        <Breadcrumbs {breadcrumbs} />
      </div>
    </div>
  {/if}
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-logo-icon.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  interface Props {
    class?: string
  }

  let { class: className, ...restProps }: Props = $props()
</script>

<svg
  height="32"
  viewBox="0 0 90 32"
  width="90"
  xmlns="http://www.w3.org/2000/svg"
  class={className}
  {...restProps}
>
  <path
    fill="currentColor"
    d="m418.082357 25.9995403v4.1135034h-7.300339v1.89854h3.684072c1.972509 0 4.072534 1.4664311 4.197997 3.9665124l.005913.2373977v1.5821167c-.087824 3.007959-2.543121 4.1390018-4.071539 4.2011773l-.132371.0027328h-7.390745v-4.0909018l7.481152-.0226016v-1.9889467l-1.190107.0007441-.346911.0008254-.084566.0003251-.127643.0007097-.044785.0003793-.055764.0007949-.016378.0008259c.000518.0004173.013246.0008384.034343.0012518l.052212.000813c.030547.0003979.066903.0007803.105225.0011355l.078131.0006709-.155385-.0004701c-.31438-.001557-.85249-.0041098-1.729029-.0080055-1.775258 0-4.081832-1.3389153-4.219994-3.9549201l-.006518-.24899v-1.423905c0-2.6982402 2.278213-4.182853 4.065464-4.2678491l.161048-.003866zm-18.691579 0v11.8658752h6.170255v4.1361051h-10.735792v-16.0019803zm-6.441475 0v16.0019803h-4.588139v-16.0019803zm-10.803597 0c1.057758 0 4.04923.7305141 4.198142 3.951222l.005768.2526881v11.7980702h-4.271715v-2.8252084h-4.136105v2.8252084h-4.407325v-11.7980702c0-1.3184306 1.004082-4.0468495 3.946899-4.197411l.257011-.0064991zm-24.147177-.0027581 8.580186.0005749c.179372.0196801 4.753355.5702841 4.753355 5.5438436s-3.775694 5.3947112-3.92376 5.4093147l-.004472.0004216 5.00569 5.0505836h-6.374959l-3.726209-3.8608906v3.8608906h-4.309831zm22.418634-2.6971669.033418.0329283s-.384228.27122-.791058.610245c-12.837747-9.4927002-20.680526-5.0175701-23.144107-3.8196818-11.187826 6.2428065-7.954768 21.5678895-7.888988 21.8737669l.001006.0046469h-17.855317s.67805-6.6900935 5.4244-14.600677c4.74635-7.9105834 12.837747-13.9000252 19.414832-14.4876686 12.681632-1.2703535 24.110975 9.7062594 24.805814 10.3864403zm-31.111679 14.1815719 2.44098.881465c.113008.8852319.273103 1.7233771.441046 2.4882761l.101394.4499406-2.7122-.9718717c-.113009-.67805-.226017-1.6499217-.27122-2.84781zm31.506724-7.6619652h-1.514312c-1.128029 0-1.333125.5900716-1.370415.8046431l-.007251.056292-.000906.0152319-.00013 3.9153864h4.136105l-.000316-3.916479c-.004939-.0795522-.08331-.8750744-1.242775-.8750744zm-50.492125.339025 2.599192.94927c-.316423.731729-.719369 1.6711108-1.011998 2.4093289l-.118085.3028712-2.599192-.94927c.226017-.610245.700652-1.7403284 1.130083-2.7122001zm35.445121-.1434449h-3.456844v3.6588673h3.434397s.98767-.3815997.98767-1.8406572-.965223-1.8182101-.965223-1.8182101zm-15.442645-.7606218 1.62732 1.2882951c-.180814.705172-.318232 1.410344-.412255 2.115516l-.06238.528879-1.830735-1.4465067c.180813-.81366.384228-1.6499217.67805-2.4861834zm4.000495-6.3058651 1.017075 1.5369134c-.39779.4158707-.766649.8317413-1.095006 1.2707561l-.238493.3339623-1.08488-1.6273201c.40683-.5198383.881465-1.0396767 1.401304-1.5143117zm-16.182794-3.3450467 1.604719 1.4013034c-.40683.4237812-.800947.8729894-1.172815 1.3285542l-.364099.4569775-1.740328-1.4917101c.519838-.5650416 1.08488-1.1300833 1.672523-1.695125zm22.398252-.0904067.497237 1.4917101c-.524359.162732-1.048717.3688592-1.573076.6068095l-.393269.1842488-.519838-1.559515c.565041-.2486184 1.22049-.4972367 1.988946-.7232534zm5.28879-.54244c.578603.0361627 1.171671.1012555 1.779204.2068505l.458361.0869712-.090406 1.4013034c-.596684-.1265694-1.193368-.2097435-1.790052-.2495224l-.447513-.0216976zm-18.555968-6.2380601 1.017075 1.559515c-.440733.2203663-.868752.4661594-1.303128.7278443l-.437201.2666291-1.039676-1.5821167c.610245-.3616267 1.197888-.67805 1.76293-.9718717zm18.601172-.8588633c1.344799.3842283 1.923513.6474959 2.155025.7707625l.037336.0202958-.090406 1.5143117c-.482169-.1958811-.964338-.381717-1.453204-.5575078l-.739158-.2561522zm-8.633837-1.3334984.452033 1.3787017h-.226016c-.491587 0-.983173.0127134-1.474759.0476754l-.491587.0427313-.429431-1.3334984c.745855-.0904067 1.469108-.13561 2.16976-.13561z"
    transform="translate(-329 -15)"
  />
</svg>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-logo.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import AppLogoIcon from "@/components/app-logo-icon.svelte"
</script>

<div
  class="bg-sidebar-primary text-sidebar-primary-foreground flex aspect-square size-8 items-center justify-center rounded-md"
>
  <AppLogoIcon class="size-5 fill-current text-white" />
</div>
<div class="ml-1 grid flex-1 text-left text-sm">
  <span class="mb-0.5 truncate leading-tight font-semibold">
    {import.meta.env.VITE_APP_NAME ?? "Svelte Starter Kit"}
  </span>
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-shell.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { Snippet } from "svelte"

  import { SidebarProvider } from "@/components/ui/sidebar"
  import * as storage from "@/lib/storage"
  import { cn } from "@/utils"

  interface Props {
    variant?: "header" | "sidebar"
    children: Snippet
    class?: string
  }

  let { variant, children, class: className }: Props = $props()

  let isOpen = $state<boolean>(storage.getItem("sidebar") !== "false")

  function handleSidebarChange(open: boolean) {
    isOpen = open
    storage.setItem("sidebar", String(open))
  }
</script>

{#if variant === "header"}
  <div class={cn("flex min-h-screen w-full flex-col", className)}>
    {@render children()}
  </div>
{:else}
  <SidebarProvider
    class={className}
    open={isOpen}
    onOpenChange={handleSidebarChange}
  >
    {@render children()}
  </SidebarProvider>
{/if}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-sidebar-header.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import Breadcrumbs from "@/components/breadcrumbs.svelte"
  import { SidebarTrigger } from "@/components/ui/sidebar"
  import type { BreadcrumbItemType } from "@/types"

  interface Props {
    breadcrumbs?: BreadcrumbItemType[]
  }

  let { breadcrumbs = [] }: Props = $props()
</script>

<header
  class="border-sidebar-border/70 flex h-16 shrink-0 items-center gap-2 border-b px-6 transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-12 md:px-4"
>
  <div class="flex items-center gap-2">
    <SidebarTrigger class="-ml-1" />
    {#if breadcrumbs && breadcrumbs.length > 0}
      <Breadcrumbs {breadcrumbs} />
    {/if}
  </div>
</header>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/app-sidebar.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Link } from "@inertiajs/svelte"
  import { BookOpen, Folder, LayoutGrid } from "@lucide/svelte"

  import NavFooter from "@/components/nav-footer.svelte"
  import NavMain from "@/components/nav-main.svelte"
  import NavUser from "@/components/nav-user.svelte"
  import {
    Sidebar,
    SidebarContent,
    SidebarFooter,
    SidebarHeader,
    SidebarMenu,
    SidebarMenuButton,
    SidebarMenuItem,
  } from "@/components/ui/sidebar"
  import { dashboard } from "@/routes"
  import { type NavItem } from "@/types"

  import AppLogo from "./app-logo.svelte"

  const mainNavItems: NavItem[] = [
    {
      title: "Dashboard",
      href: dashboard.index().url,
      icon: LayoutGrid,
    },
  ]

  const footerNavItems: NavItem[] = [
    {
      title: "Github Repo",
      href: "https://github.com/inertia-rails/svelte-starter-kit",
      icon: Folder,
    },
    {
      title: "Documentation",
      href: "https://inertia-rails.dev",
      icon: BookOpen,
    },
  ]
</script>

<Sidebar collapsible="icon" variant="inset">
  <SidebarHeader>
    <SidebarMenu>
      <SidebarMenuItem>
        <SidebarMenuButton size="lg">
          {#snippet child({ props })}
            <Link {...props} href={dashboard.index()}>
              <AppLogo />
            </Link>
          {/snippet}
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  </SidebarHeader>

  <SidebarContent>
    <NavMain items={mainNavItems} />
  </SidebarContent>

  <SidebarFooter>
    <NavFooter items={footerNavItems} />
    <NavUser />
  </SidebarFooter>
</Sidebar>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/appearance-tabs.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Monitor, Moon, Sun } from "@lucide/svelte"

  import { useAppearanceSvelte } from "@/runes/use-appearance.svelte"

  const appearance = useAppearanceSvelte()

  const tabs = [
    { value: "light", Icon: Sun, label: "Light" },
    { value: "dark", Icon: Moon, label: "Dark" },
    { value: "system", Icon: Monitor, label: "System" },
  ] as const
</script>

<div
  class="inline-flex gap-1 rounded-lg bg-neutral-100 p-1 dark:bg-neutral-800"
>
  {#each tabs as { value, Icon, label } (value)}
    <button
      onclick={() => appearance.update(value)}
      class={[
        "flex items-center rounded-md px-3.5 py-1.5 transition-colors",
        appearance.value === value
          ? "bg-white shadow-xs dark:bg-neutral-700 dark:text-neutral-100"
          : "text-neutral-500 hover:bg-neutral-200/60 hover:text-black dark:text-neutral-400 dark:hover:bg-neutral-700/60",
      ].join(" ")}
    >
      <Icon class="-ml-1 h-4 w-4" />
      <span class="ml-1.5 text-sm">{label}</span>
    </button>
  {/each}
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/breadcrumbs.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Link } from "@inertiajs/svelte"

  import {
    Breadcrumb,
    BreadcrumbItem,
    BreadcrumbLink,
    BreadcrumbList,
    BreadcrumbPage,
    BreadcrumbSeparator,
  } from "@/components/ui/breadcrumb"

  interface BreadcrumbItemType {
    title: string
    href?: string
  }

  interface Props {
    breadcrumbs: BreadcrumbItemType[]
  }

  let { breadcrumbs }: Props = $props()
</script>

<Breadcrumb>
  <BreadcrumbList>
    {#each breadcrumbs as item, index (index)}
      <BreadcrumbItem>
        {#if index === breadcrumbs.length - 1}
          <BreadcrumbPage>{item.title}</BreadcrumbPage>
        {:else}
          <BreadcrumbLink>
            {#snippet child({ props: { class: className, "data-slot": dataSlot } })}
              <Link class={className} data-slot={dataSlot} href={item.href ?? "#"}>{item.title}</Link>
            {/snippet}
          </BreadcrumbLink>
        {/if}
      </BreadcrumbItem>
      {#if index !== breadcrumbs.length - 1}
        <BreadcrumbSeparator />
      {/if}
    {/each}
  </BreadcrumbList>
</Breadcrumb>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/delete-user.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"

  import HeadingSmall from "@/components/heading-small.svelte"
  import InputError from "@/components/input-error.svelte"
  import { Button } from "@/components/ui/button"
  import * as Dialog from "@/components/ui/dialog"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import { users } from "@/routes"

  let passwordInput: HTMLInputElement | null = null
</script>

<div class="space-y-6">
  <HeadingSmall
    title="Delete account"
    description="Delete your account and all of its resources"
  />
  <div
    class="space-y-4 rounded-lg border border-red-100 bg-red-50 p-4 dark:border-red-200/10 dark:bg-red-700/10"
  >
    <div class="relative space-y-0.5 text-red-600 dark:text-red-100">
      <p class="font-medium">Warning</p>
      <p class="text-sm">Please proceed with caution, this cannot be undone.</p>
    </div>
    <Dialog.Root>
      <Dialog.Trigger>
        <Button variant="destructive">Delete account</Button>
      </Dialog.Trigger>
      <Dialog.Content>
        <Form
          action={users.destroy()}
          options={{
            preserveScroll: true,
          }}
          onError={() => passwordInput?.focus()}
          resetOnSuccess
          class="space-y-6"
        >
          {#snippet children({
            errors,
            processing,
            resetAndClearErrors,
          }: FormComponentSlotProps)}
            <Dialog.Header class="space-y-3">
              <Dialog.Title>
                Are you sure you want to delete your account?
              </Dialog.Title>
              <Dialog.Description>
                Once your account is deleted, all of its resources and data will
                also be permanently deleted. Please enter your password to
                confirm you would like to permanently delete your account.
              </Dialog.Description>
            </Dialog.Header>

            <div class="grid gap-2">
              <Label for="password_challenge" class="sr-only">Password</Label>
              <Input
                id="password_challenge"
                type="password"
                name="password_challenge"
                bind:ref={passwordInput}
                placeholder="Password"
              />
              <InputError messages={errors.password_challenge} />
            </div>

            <Dialog.Footer class="gap-2">
              <Dialog.Close>
                {#snippet child()}
                  <Button
                    variant="secondary"
                    onclick={() => resetAndClearErrors()}>Cancel</Button
                  >
                {/snippet}
              </Dialog.Close>

              <Button type="submit" variant="destructive" disabled={processing}>
                Delete account
              </Button>
            </Dialog.Footer>
          {/snippet}
        </Form>
      </Dialog.Content>
    </Dialog.Root>
  </div>
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/heading-small.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  interface Props {
    title: string
    description?: string
  }

  let { title, description }: Props = $props()
</script>

<header>
  <h3 class="mb-0.5 text-base font-medium">{title}</h3>
  {#if description}
    <p class="text-muted-foreground text-sm">
      {description}
    </p>
  {/if}
</header>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/heading.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  interface Props {
    title: string
    description?: string
  }

  let { title, description }: Props = $props()
</script>

<div class="mb-8 space-y-0.5">
  <h2 class="text-xl font-semibold tracking-tight">{title}</h2>
  {#if description}
    <p class="text-muted-foreground text-sm">
      {description}
    </p>
  {/if}
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/icon.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import * as icons from "@lucide/svelte"
  import type { Component } from "svelte"

  import { cn } from "@/utils"

  interface Props {
    name: string
    class?: string
    size?: number | string
    color?: string
    strokeWidth?: number | string
  }

  let {
    name,
    class: className = "",
    size = 16,
    color,
    strokeWidth = 2,
  }: Props = $props()

  const computedClass = $derived(cn("h-4 w-4", className))

  const IconComponent = $derived(() => {
    const iconName = name.charAt(0).toUpperCase() + name.slice(1)
    return (icons as Record<string, unknown>)[iconName] as Component
  })
</script>

<IconComponent
  class={computedClass}
  {size}
  stroke-width={strokeWidth}
  {color}
/>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/input-error.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { cn } from "@/utils"

  interface Props {
    messages?: string[]
    class?: string
  }

  let { messages, class: className }: Props = $props()
</script>

{#if messages}
  <div>
    <p class={cn("text-sm text-red-600 dark:text-red-500", className)}>
      {messages.join(", ")}
    </p>
  </div>
{/if}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/nav-footer.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import * as Sidebar from "@/components/ui/sidebar"
  import { type NavItem } from "@/types"

  interface Props {
    items: NavItem[]
    class?: string
  }

  let { items, class: className = "" }: Props = $props()
</script>

<Sidebar.Group class={`group-data-[collapsible=icon]:p-0 ${className}`}>
  <Sidebar.GroupContent>
    <Sidebar.Menu>
      {#each items as item (item.title)}
        <Sidebar.MenuItem>
          <Sidebar.MenuButton
            class="text-neutral-600 hover:text-neutral-800 dark:text-neutral-300 dark:hover:text-neutral-100"
          >
            {#snippet child({ props })}
              <a
                href={item.href}
                target="_blank"
                rel="noopener noreferrer"
                {...props}
              >
                <item.icon />
                <span>{item.title}</span>
              </a>
            {/snippet}
          </Sidebar.MenuButton>
        </Sidebar.MenuItem>
      {/each}
    </Sidebar.Menu>
  </Sidebar.GroupContent>
</Sidebar.Group>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/nav-main.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Link, page } from "@inertiajs/svelte"

  import * as Sidebar from "@/components/ui/sidebar"
  import type { NavItem } from "@/types"

  interface Props {
    items: NavItem[]
  }

  let { items }: Props = $props()
</script>

<Sidebar.Group class="px-2 py-0">
  <Sidebar.GroupLabel>Platform</Sidebar.GroupLabel>
  <Sidebar.Menu>
    {#each items as item (item.title)}
      <Sidebar.MenuItem>
        <Sidebar.MenuButton
          isActive={item.href === page.url}
          tooltipContent={item.title}
        >
          {#snippet child({ props })}
            <Link href={item.href} {...props}>
              <item.icon />
              <span>{item.title}</span>
            </Link>
          {/snippet}
        </Sidebar.MenuButton>
      </Sidebar.MenuItem>
    {/each}
  </Sidebar.Menu>
</Sidebar.Group>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/nav-user.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { page } from "@inertiajs/svelte"
  import { ChevronsUpDown } from "@lucide/svelte"

  import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuTrigger,
  } from "@/components/ui/dropdown-menu"
  import {
    SidebarMenu,
    SidebarMenuButton,
    SidebarMenuItem,
    useSidebar,
  } from "@/components/ui/sidebar"
  import UserInfo from "@/components/user-info.svelte"
  import UserMenuContent from "@/components/user-menu-content.svelte"
  import { type User } from "@/types"

  const auth = $derived(
    page.props.auth as { user: User; session: { id: number } },
  )
  const { isMobile, state } = useSidebar()
</script>

<SidebarMenu>
  <SidebarMenuItem>
    <DropdownMenu>
      <DropdownMenuTrigger>
        {#snippet child({ props })}
          <SidebarMenuButton
            {...props}
            size="lg"
            class="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
          >
            <UserInfo user={auth.user} />
            <ChevronsUpDown class="ml-auto size-4" />
          </SidebarMenuButton>
        {/snippet}
      </DropdownMenuTrigger>
      <DropdownMenuContent
        class="w-(--reka-dropdown-menu-trigger-width) min-w-56 rounded-lg"
        side={isMobile ? "bottom" : state === "collapsed" ? "left" : "bottom"}
        align="end"
        sideOffset={4}
      >
        <UserMenuContent {auth} />
      </DropdownMenuContent>
    </DropdownMenu>
  </SidebarMenuItem>
</SidebarMenu>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/placeholder-pattern.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  const patternId = `pattern-${Math.random().toString(36).substring(2, 9)}`
</script>

<svg
  class="absolute inset-0 size-full stroke-neutral-900/20 dark:stroke-neutral-100/20"
  fill="none"
>
  <defs>
    <pattern
      id={patternId}
      x="0"
      y="0"
      width="8"
      height="8"
      patternUnits="userSpaceOnUse"
    >
      <path d="M-1 5L5 -1M3 9L8.5 3.5" stroke-width="0.5"></path>
    </pattern>
  </defs>
  <rect stroke="none" fill={`url(#${patternId})`} width="100%" height="100%"
  ></rect>
</svg>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/resource-item.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  interface Props {
    href: string
    text: string
  }

  let { href, text }: Props = $props()
</script>

<span
  class="flex h-3.5 w-3.5 items-center justify-center rounded-full border border-[#e3e3e0] bg-[#FDFDFC] shadow-[0px_0px_1px_0px_rgba(0,0,0,0.03),0px_1px_2px_0px_rgba(0,0,0,0.06)] dark:border-[#3E3E3A] dark:bg-[#161615]"
>
  <span class="h-1.5 w-1.5 rounded-full bg-[#dbdbd7] dark:bg-[#3E3E3A]"></span>
</span>
<a
  {href}
  target="_blank"
  class="inline-flex items-center space-x-1 font-medium text-[#f53003] underline underline-offset-4 dark:text-[#FF4433]"
  rel="noreferrer"
>
  <span>{text}</span>
  <svg width="10" height="11" viewBox="0 0 10 11" class="h-2.5 w-2.5">
    <path
      d="M7.70833 6.95834V2.79167H3.54167M2.5 8L7.5 3.00001"
      stroke="currentColor"
      stroke-linecap="square"
    />
  </svg>
</a>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/text-link.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { LinkComponentBaseProps, Method } from "@inertiajs/core"
  import { Link } from "@inertiajs/svelte"
  import type { Snippet } from "svelte"

  import { cn } from "@/utils"

  interface Props {
    href: NonNullable<LinkComponentBaseProps["href"]>
    tabindex?: number
    method?: Method
    as?: keyof HTMLElementTagNameMap
    children: Snippet
    class?: string
  }

  let {
    href,
    tabindex,
    method,
    as,
    class: className,
    children,
  }: Props = $props()
</script>

<Link
  {href}
  {tabindex}
  {as}
  {method}
  class={cn(
    "text-foreground underline decoration-neutral-300 underline-offset-4 transition-colors duration-300 ease-out hover:decoration-current! dark:decoration-neutral-500",
    className,
  )}
>
  {@render children()}
</Link>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/user-info.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
  import { useInitials } from "@/runes/use-initials"
  import type { User } from "@/types"

  interface Props {
    user: User
    showEmail?: boolean
  }

  let { user, showEmail = false }: Props = $props()

  const { getInitials } = useInitials()

  const showAvatar = $derived(user.avatar && user.avatar !== "")
</script>

<Avatar class="h-8 w-8 overflow-hidden rounded-lg">
  {#if showAvatar}
    <AvatarImage src={user.avatar} alt={user.name} />
  {/if}
  <AvatarFallback class="rounded-lg text-black dark:text-white">
    {getInitials(user.name)}
  </AvatarFallback>
</Avatar>

<div class="grid flex-1 text-left text-sm leading-tight">
  <span class="truncate font-medium">{user.name}</span>
  {#if showEmail}
    <span class="text-muted-foreground truncate text-xs">
      {user.email}
    </span>
  {/if}
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/components/user-menu-content.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Link, router } from "@inertiajs/svelte"
  import { LogOut, Settings } from "@lucide/svelte"

  import {
    DropdownMenuGroup,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
  } from "@/components/ui/dropdown-menu"
  import UserInfo from "@/components/user-info.svelte"
  import { sessions, settingsProfiles } from "@/routes"
  import type { User } from "@/types"

  interface Props {
    auth: {
      session: {
        id: number
      }
      user: User
    }
  }

  let { auth }: Props = $props()

  const handleLogout = () => {
    router.flushAll()
  }
</script>

<DropdownMenuLabel class="p-0 font-normal">
  <div class="flex items-center gap-2 px-1 py-1.5 text-left text-sm">
    <UserInfo user={auth.user} showEmail={true} />
  </div>
</DropdownMenuLabel>
<DropdownMenuSeparator />
<DropdownMenuGroup>
  <DropdownMenuItem class="w-full">
    {#snippet child({ props })}
      <Link
        href={settingsProfiles.show()}
        data-sveltekit-prefetch
        as="button"
        {...props}
      >
        <Settings class="mr-2 h-4 w-4" />
        Settings
      </Link>
    {/snippet}
  </DropdownMenuItem>
</DropdownMenuGroup>
<DropdownMenuSeparator />
<DropdownMenuItem class="w-full">
  {#snippet child({ props })}
    <Link
      href={sessions.destroy(auth.session.id)}
      as="button"
      onclick={handleLogout}
      {...props}
    >
      <LogOut class="mr-2 h-4 w-4" />
      Log out
    </Link>
  {/snippet}
</DropdownMenuItem>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/entrypoints/inertia.ts", ERB.new(
    *[
  <<~'TCODE'
import { createInertiaApp } from "@inertiajs/svelte"

import PersistentLayout from "@/layouts/persistent-layout.svelte"
import { initializeTheme } from "@/runes/use-appearance.svelte"

createInertiaApp({
  pages: "../pages",
  layout: () => PersistentLayout,
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: "brackets",
    }),
  },
  progress: {
    color: "#4B5563",
  },
})

// This will set light / dark mode on page load...
initializeTheme()
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/app-layout.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { Snippet } from "svelte"

  import AppLayout from "@/layouts/app/app-sidebar-layout.svelte"
  import type { BreadcrumbItemType } from "@/types"

  interface Props {
    breadcrumbs?: BreadcrumbItemType[]
    children: Snippet
  }

  let { breadcrumbs = [], children }: Props = $props()
</script>

<AppLayout {breadcrumbs}>
  {@render children()}
</AppLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/app/app-header-layout.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { Snippet } from "svelte"

  import AppContent from "@/components/app-content.svelte"
  import AppHeader from "@/components/app-header.svelte"
  import AppShell from "@/components/app-shell.svelte"
  import type { BreadcrumbItemType } from "@/types"

  interface Props {
    breadcrumbs?: BreadcrumbItemType[]
    children: Snippet
  }

  let { breadcrumbs = [], children }: Props = $props()
</script>

<AppShell class="flex-col">
  <AppHeader {breadcrumbs} />
  <AppContent>
    {@render children()}
  </AppContent>
</AppShell>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/app/app-sidebar-layout.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { Snippet } from "svelte"

  import AppContent from "@/components/app-content.svelte"
  import AppShell from "@/components/app-shell.svelte"
  import AppSidebarHeader from "@/components/app-sidebar-header.svelte"
  import AppSidebar from "@/components/app-sidebar.svelte"
  import type { BreadcrumbItemType } from "@/types"

  interface Props {
    breadcrumbs?: BreadcrumbItemType[]
    children: Snippet
  }

  let { breadcrumbs = [], children }: Props = $props()
</script>

<AppShell variant="sidebar">
  <AppSidebar />
  <AppContent variant="sidebar" class="overflow-x-hidden">
    <AppSidebarHeader {breadcrumbs} />
    {@render children()}
  </AppContent>
</AppShell>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth-layout.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { Snippet } from "svelte"

  import AuthLayout from "@/layouts/auth/auth-simple-layout.svelte"

  interface Props {
    title?: string
    description?: string
    children: Snippet
  }

  let { title, description, children }: Props = $props()
</script>

<AuthLayout {title} {description}>
  {@render children()}
</AuthLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth/auth-card-layout.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Link } from "@inertiajs/svelte"
  import type { Snippet } from "svelte"

  import AppLogoIcon from "@/components/app-logo-icon.svelte"
  import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
  } from "@/components/ui/card"
  import { home } from "@/routes"

  interface Props {
    title?: string
    description?: string
    children: Snippet
  }

  let { title, description, children }: Props = $props()
</script>

<div
  class="bg-muted flex min-h-svh flex-col items-center justify-center gap-6 p-6 md:p-10"
>
  <div class="flex w-full max-w-md flex-col gap-6">
    <Link
      href={home.index()}
      class="flex items-center gap-2 self-center font-medium"
    >
      <div class="flex h-9 w-9 items-center justify-center">
        <AppLogoIcon class="size-9 fill-current text-black dark:text-white" />
      </div>
    </Link>

    <div class="flex flex-col gap-6">
      <Card class="rounded-xl">
        <CardHeader class="px-10 pt-8 pb-0 text-center">
          <CardTitle class="text-xl">{title}</CardTitle>
          <CardDescription>
            {description}
          </CardDescription>
        </CardHeader>
        <CardContent class="px-10 py-8">
          {@render children()}
        </CardContent>
      </Card>
    </div>
  </div>
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth/auth-simple-layout.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Link } from "@inertiajs/svelte"
  import type { Snippet } from "svelte"

  import AppLogoIcon from "@/components/app-logo-icon.svelte"
  import { home } from "@/routes"

  interface Props {
    title?: string
    description?: string
    children: Snippet
  }

  let { title, description, children }: Props = $props()
</script>

<div
  class="bg-background flex min-h-svh flex-col items-center justify-center gap-6 p-6 md:p-10"
>
  <div class="w-full max-w-sm">
    <div class="flex flex-col gap-8">
      <div class="flex flex-col items-center gap-4">
        <Link
          href={home.index()}
          class="flex flex-col items-center gap-2 font-medium"
        >
          <div class="mb-1 flex size-14 items-center justify-center rounded-md">
            <AppLogoIcon
              class="size-14 fill-current text-[var(--foreground)] dark:text-white"
            />
          </div>
          <span class="sr-only">{title}</span>
        </Link>
        <div class="space-y-2 text-center">
          <h1 class="text-xl font-medium">{title}</h1>
          <p class="text-muted-foreground text-center text-sm">
            {description}
          </p>
        </div>
      </div>
      {@render children()}
    </div>
  </div>
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/auth/auth-split-layout.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Link } from "@inertiajs/svelte"
  import type { Snippet } from "svelte"

  import AppLogoIcon from "@/components/app-logo-icon.svelte"
  import { home } from "@/routes"

  interface Props {
    title?: string
    description?: string
    children: Snippet
  }

  let { title, description, children }: Props = $props()
</script>

<div
  class="relative grid h-dvh flex-col items-center justify-center px-8 sm:px-0 lg:max-w-none lg:grid-cols-2 lg:px-0"
>
  <div
    class="bg-muted relative hidden h-full flex-col p-10 text-white lg:flex dark:border-r"
  >
    <div class="absolute inset-0 bg-zinc-900"></div>
    <Link
      href={home.index()}
      class="relative z-20 flex items-center text-lg font-medium"
    >
      <AppLogoIcon class="mr-2 size-8 fill-current text-white" />
      {import.meta.env.VITE_APP_NAME ?? "Svelte Starter Kit"}
    </Link>
    <div class="relative z-20 mt-auto">
      <blockquote class="space-y-2">
        <p class="text-lg">
          &ldquo;The One Person Framework. A toolkit so powerful that it allows
          a single individual to create modern applications upon which they
          might build a competitive business.&rdquo;
        </p>
        <footer class="text-sm text-neutral-300">DHH</footer>
      </blockquote>
    </div>
  </div>
  <div class="lg:p-8">
    <div
      class="mx-auto flex w-full flex-col justify-center space-y-6 sm:w-[350px]"
    >
      <div class="flex flex-col space-y-2 text-center">
        {#if title}
          <h1 class="text-xl font-medium tracking-tight">
            {title}
          </h1>
        {/if}
        {#if description}
          <p class="text-muted-foreground text-sm">
            {description}
          </p>
        {/if}
      </div>
      {@render children()}
    </div>
  </div>
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/persistent-layout.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { Snippet } from "svelte"

  import { Toaster } from "@/components/ui/sonner"
  import { useFlash } from "@/runes/use-flash.svelte"

  interface Props {
    children: Snippet
  }

  let { children }: Props = $props()

  useFlash()
</script>

{@render children()}
<Toaster richColors />
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/layouts/settings/layout.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Link, page } from "@inertiajs/svelte"
  import type { Snippet } from "svelte"

  import Heading from "@/components/heading.svelte"
  import { Button } from "@/components/ui/button"
  import { Separator } from "@/components/ui/separator"
  import {
    settingsAppearance,
    settingsEmails,
    settingsPasswords,
    settingsProfiles,
    settingsSessions,
  } from "@/routes"
  import { type NavItem } from "@/types"

  interface Props {
    children: Snippet
  }

  let { children }: Props = $props()

  const sidebarNavItems: NavItem[] = [
    {
      title: "Profile",
      href: settingsProfiles.show().url,
    },
    {
      title: "Email",
      href: settingsEmails.show().url,
    },
    {
      title: "Password",
      href: settingsPasswords.show().url,
    },
    {
      title: "Sessions",
      href: settingsSessions.index().url,
    },
    {
      title: "Appearance",
      href: settingsAppearance().url,
    },
  ]
</script>

<div class="px-4 py-6">
  <Heading
    title="Settings"
    description="Manage your profile and account settings"
  />

  <div class="flex flex-col lg:flex-row lg:space-x-12">
    <aside class="w-full max-w-xl lg:w-48">
      <nav class="flex flex-col space-y-1 space-x-0">
        {#each sidebarNavItems as item (item.href)}
          <Button
            variant="ghost"
            class="w-full justify-start {page.url === item.href
              ? 'bg-muted'
              : ''}"
          >
            <Link href={item.href} class="flex w-full items-start">
              {item.title}
            </Link>
          </Button>
        {/each}
      </nav>
    </aside>

    <Separator class="my-6 lg:hidden" />

    <div class="flex-1 md:max-w-2xl">
      <section class="max-w-xl space-y-12">
        {@render children()}
      </section>
    </div>
  </div>
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/dashboard/index.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  // import { Head } from "@inertiajs/svelte"

  import PlaceholderPattern from "@/components/placeholder-pattern.svelte"
  import AppLayout from "@/layouts/app-layout.svelte"
  import { dashboard } from "@/routes"
  import { type BreadcrumbItem } from "@/types"

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Dashboard",
      href: dashboard.index().url,
    },
  ]
</script>

<svelte:head>
  <title>{breadcrumbs[breadcrumbs.length - 1].title}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-1 flex-col gap-4 overflow-x-auto rounded-xl p-4">
    <div class="grid auto-rows-min gap-4 md:grid-cols-3">
      <div
        class="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border"
      >
        <PlaceholderPattern />
      </div>
      <div
        class="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border"
      >
        <PlaceholderPattern />
      </div>
      <div
        class="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border"
      >
        <PlaceholderPattern />
      </div>
    </div>
    <div
      class="border-sidebar-border/70 dark:border-sidebar-border relative min-h-[100vh] flex-1 rounded-xl border md:min-h-min"
    >
      <PlaceholderPattern />
    </div>
  </div>
</AppLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/home/index.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { Link, page } from "@inertiajs/svelte"

  import AppLogoIcon from "@/components/app-logo-icon.svelte"
  import ResourceItem from "@/components/resource-item.svelte"
  import { dashboard, sessions, users } from "@/routes"

  const links = [
    [
      {
        text: "Inertia Rails Docs",
        href: "https://inertia-rails.dev",
      },
      {
        text: "shadcn-svelte Components",
        href: "https://www.shadcn-svelte.com",
      },
      {
        text: "Svelte Docs",
        href: "https://svelte.dev",
      },
      {
        text: "Rails Guides",
        href: "https://guides.rubyonrails.org",
      },
    ],
  ]
</script>

<svelte:head>
  <link rel="preconnect" href="https://rsms.me/" />
  <link rel="stylesheet" href="https://rsms.me/inter/inter.css" />
</svelte:head>

<div
  class="flex min-h-screen flex-col items-center bg-[#FDFDFC] p-6 text-[#1b1b18] lg:justify-center lg:p-8 dark:bg-[#0a0a0a]"
>
  <header
    class="mb-6 w-full max-w-[335px] text-sm not-has-[nav]:hidden lg:max-w-4xl"
  >
    <nav class="flex items-center justify-end gap-4">
      {#if page.props.auth.user}
        <Link
          href={dashboard.index()}
          class="inline-block rounded-sm border border-[#19140035] px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#1915014a] dark:border-[#3E3E3A] dark:text-[#EDEDEC] dark:hover:border-[#62605b]"
        >
          Dashboard
        </Link>
      {:else}
        <Link
          href={sessions.new()}
          class="inline-block rounded-sm border border-transparent px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#19140035] dark:text-[#EDEDEC] dark:hover:border-[#3E3E3A]"
        >
          Log in
        </Link>
        <Link
          href={users.new()}
          class="inline-block rounded-sm border border-[#19140035] px-5 py-1.5 text-sm leading-normal text-[#1b1b18] hover:border-[#1915014a] dark:border-[#3E3E3A] dark:text-[#EDEDEC] dark:hover:border-[#62605b]"
        >
          Register
        </Link>
      {/if}
    </nav>
  </header>
  <div
    class="flex w-full items-center justify-center opacity-100 transition-opacity duration-750 lg:grow starting:opacity-0"
  >
    <main
      class="flex w-full max-w-[335px] flex-col-reverse overflow-hidden rounded-lg lg:max-w-4xl lg:flex-row"
    >
      <div
        class="flex-1 rounded-br-lg rounded-bl-lg bg-white p-6 pb-12 text-[13px] leading-[20px] shadow-[inset_0px_0px_0px_1px_rgba(26,26,0,0.16)] lg:rounded-tl-lg lg:rounded-br-none lg:p-20 dark:bg-[#161615] dark:text-[#EDEDEC] dark:shadow-[inset_0px_0px_0px_1px_#fffaed2d]"
      >
        <h1 class="mb-1 font-medium">
          {import.meta.env.VITE_APP_NAME ?? "Svelte Starter Kit"}
        </h1>
        <p class="mb-2 text-[#706f6c] dark:text-[#A1A09A]">
          Rails + Inertia.js + Svelte + shadcn-svelte
          <br />
          Here are some resources to begin:
        </p>

        <ul class="mb-4 flex flex-col lg:mb-6">
          {#each links[0] as link, index (index)}
            <li class="relative flex items-center gap-4 py-2">
              <ResourceItem text={link.text} href={link.href} />
            </li>
          {/each}
        </ul>
        <ul class="flex gap-3 text-sm leading-normal">
          <li>
            <a
              href="https://inertia-rails.dev"
              target="_blank"
              class="inline-block rounded-sm border border-black bg-[#1b1b18] px-5 py-1.5 text-sm leading-normal text-white hover:border-black hover:bg-black dark:border-[#eeeeec] dark:bg-[#eeeeec] dark:text-[#1C1C1A] dark:hover:border-white dark:hover:bg-white"
            >
              Learn more
            </a>
          </li>
        </ul>
      </div>

      <div
        class="relative -mb-px aspect-[335/376] w-full shrink-0 overflow-hidden rounded-t-lg bg-[#D30001] p-10 text-white lg:mb-0 lg:-ml-px lg:aspect-auto lg:w-[438px] lg:rounded-t-none lg:rounded-r-lg"
      >
        <AppLogoIcon class="h-full w-full" />
      </div>
    </main>
  </div>
</div>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/identity/password_resets/edit.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import { LoaderCircle } from "@lucide/svelte"

  import InputError from "@/components/input-error.svelte"
  import { Button } from "@/components/ui/button"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import AuthLayout from "@/layouts/auth-layout.svelte"
  import { identityPasswordResets } from "@/routes"

  interface Props {
    sid: string
    email: string
  }

  let { sid, email }: Props = $props()
</script>

<svelte:head>
  <title>Reset password</title>
</svelte:head>

<AuthLayout
  title="Reset password"
  description="Please enter your new password below"
>
  <Form
    action={identityPasswordResets.update()}
    transform={(data) => ({ ...data, sid, email })}
    resetOnSuccess={["password", "password_confirmation"]}
  >
    {#snippet children({ errors, processing }: FormComponentSlotProps)}
      <div class="grid gap-6">
        <div class="grid gap-2">
          <Label for="email">Email</Label>
          <Input
            id="email"
            name="email"
            type="email"
            autocomplete="email"
            value={email}
            class="mt-1 block w-full"
            readonly
          />
          <InputError messages={errors.email} class="mt-2" />
        </div>

        <div class="grid gap-2">
          <Label for="password">Password</Label>
          <Input
            id="password"
            name="password"
            type="password"
            autocomplete="new-password"
            class="mt-1 block w-full"
            autofocus
            placeholder="Password"
          />
          <InputError messages={errors.password} />
        </div>

        <div class="grid gap-2">
          <Label for="password_confirmation">Confirm Password</Label>
          <Input
            id="password_confirmation"
            name="password_confirmation"
            type="password"
            autocomplete="new-password"
            class="mt-1 block w-full"
            placeholder="Confirm password"
          />
          <InputError messages={errors.password_confirmation} />
        </div>

        <Button type="submit" class="mt-4 w-full" disabled={processing}>
          {#if processing}
            <LoaderCircle class="h-4 w-4 animate-spin" />
          {/if}
          Reset password
        </Button>
      </div>
    {/snippet}
  </Form>
</AuthLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/identity/password_resets/new.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import { LoaderCircle } from "@lucide/svelte"

  import InputError from "@/components/input-error.svelte"
  import TextLink from "@/components/text-link.svelte"
  import { Button } from "@/components/ui/button"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import AuthLayout from "@/layouts/auth-layout.svelte"
  import { identityPasswordResets, sessions } from "@/routes"
</script>

<svelte:head>
  <title>Forgot password</title>
</svelte:head>

<AuthLayout
  title="Forgot password"
  description="Enter your email to receive a password reset link"
>
  <div class="space-y-6">
    <Form action={identityPasswordResets.create()}>
      {#snippet children({ errors, processing }: FormComponentSlotProps)}
        <div class="grid gap-2">
          <Label for="email">Email address</Label>
          <Input
            id="email"
            name="email"
            type="email"
            autocomplete="off"
            autofocus
            placeholder="email@example.com"
          />
          <InputError messages={errors.email} />
        </div>

        <div class="my-6 flex items-center justify-start">
          <Button type="submit" class="w-full" disabled={processing}>
            {#if processing}
              <LoaderCircle class="h-4 w-4 animate-spin" />
            {/if}
            Email password reset link
          </Button>
        </div>
      {/snippet}
    </Form>

    <div class="text-muted-foreground space-x-1 text-center text-sm">
      <span>Or, return to</span>
      <TextLink href={sessions.new()}>log in</TextLink>
    </div>
  </div>
</AuthLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/sessions/new.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import { LoaderCircle } from "@lucide/svelte"

  import InputError from "@/components/input-error.svelte"
  import TextLink from "@/components/text-link.svelte"
  import { Button } from "@/components/ui/button"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import AuthBase from "@/layouts/auth-layout.svelte"
  import { identityPasswordResets, sessions, users } from "@/routes"
</script>

<svelte:head>
  <title>Log in</title>
</svelte:head>

<AuthBase
  title="Log in to your account"
  description="Enter your email and password below to log in"
>
  <Form
    action={sessions.create()}
    resetOnSuccess={["password"]}
    class="flex flex-col gap-6"
  >
    {#snippet children({ processing, errors }: FormComponentSlotProps)}
      <div class="grid gap-6">
        <div class="grid gap-2">
          <Label for="email">Email address</Label>
          <Input
            id="email"
            name="email"
            type="email"
            required
            autofocus
            tabindex={1}
            autocomplete="email"
            placeholder="email@example.com"
          />
          <InputError messages={errors.email} />
        </div>

        <div class="grid gap-2">
          <div class="flex items-center justify-between">
            <Label for="password">Password</Label>
            <TextLink
              href={identityPasswordResets.new()}
              class="text-sm"
              tabindex={5}
            >
              Forgot password?
            </TextLink>
          </div>
          <Input
            id="password"
            name="password"
            type="password"
            required
            tabindex={2}
            autocomplete="current-password"
            placeholder="Password"
          />
          <InputError messages={errors.password} />
        </div>

        <Button
          type="submit"
          class="mt-4 w-full"
          tabindex={4}
          disabled={processing}
        >
          {#if processing}
            <LoaderCircle class="h-4 w-4 animate-spin" />
          {/if}
          Log in
        </Button>
      </div>

      <div class="text-muted-foreground text-center text-sm">
        Don't have an account?
        <TextLink href={users.new()} tabindex={5}>Sign up</TextLink>
      </div>
    {/snippet}
  </Form>
</AuthBase>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/appearance.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import AppearanceTabs from "@/components/appearance-tabs.svelte"
  import HeadingSmall from "@/components/heading-small.svelte"
  import AppLayout from "@/layouts/app-layout.svelte"
  import SettingsLayout from "@/layouts/settings/layout.svelte"
  import { settingsAppearance } from "@/routes"
  import { type BreadcrumbItem } from "@/types"

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Appearance settings",
      href: settingsAppearance().url,
    },
  ]
</script>

<svelte:head>
  <title>{breadcrumbs[breadcrumbs.length - 1].title}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <SettingsLayout>
    <div class="space-y-6">
      <HeadingSmall
        title="Appearance settings"
        description="Update your account's appearance settings"
      />
      <AppearanceTabs />
    </div>
  </SettingsLayout>
</AppLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/emails/show.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form, router } from "@inertiajs/svelte"
  import { page } from "@inertiajs/svelte"
  import { fly } from "svelte/transition"

  import HeadingSmall from "@/components/heading-small.svelte"
  import InputError from "@/components/input-error.svelte"
  import { Button } from "@/components/ui/button"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import AppLayout from "@/layouts/app-layout.svelte"
  import SettingsLayout from "@/layouts/settings/layout.svelte"
  import { identityEmailVerifications, settingsEmails } from "@/routes"
  import type { BreadcrumbItem } from "@/types"

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Email settings",
      href: settingsEmails.show().url,
    },
  ]

  const user = $derived(page.props.auth.user)

  const resendVerification = () => {
    router.post(identityEmailVerifications.create().url)
  }
</script>

<svelte:head>
  <title>{breadcrumbs[breadcrumbs.length - 1].title}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <SettingsLayout>
    <div class="space-y-6">
      <HeadingSmall
        title="Update email"
        description="Update your email address and verify it"
      />

      <Form
        action={settingsEmails.update()}
        options={{
          preserveScroll: true,
        }}
        resetOnError={["password_challenge"]}
        resetOnSuccess={["password_challenge"]}
        class="space-y-6"
      >
        {#snippet children({
          errors,
          processing,
          recentlySuccessful,
        }: FormComponentSlotProps)}
          <div class="grid gap-2">
            <Label for="email">Email address</Label>

            <Input
              id="email"
              name="email"
              type="email"
              class="mt-1 block w-full"
              defaultValue={page.props.auth.user.email}
              required
              autocomplete="username"
              placeholder="Email address"
            />

            <InputError class="mt-2" messages={errors.email} />
          </div>

          {#if !user.verified}
            <div>
              <p class="text-muted-foreground -mt-4 text-sm">
                Your email address is unverified.
                <button
                  type="button"
                  onclick={resendVerification}
                  class="text-foreground underline decoration-neutral-300 underline-offset-4 transition-colors duration-300 ease-out hover:decoration-current! dark:decoration-neutral-500"
                >
                  Click here to resend the verification email.
                </button>
              </p>
            </div>
          {/if}

          <div class="grid gap-2">
            <Label for="password_challenge">Current password</Label>

            <Input
              id="password_challenge"
              name="password_challenge"
              type="password"
              class="mt-1 block w-full"
              autocomplete="current-password"
              placeholder="Current password"
            />

            <InputError messages={errors.password_challenge} />
          </div>

          <div class="flex items-center gap-4">
            <Button type="submit" disabled={processing}>Save</Button>

            {#if recentlySuccessful}
              <p
                class="text-sm text-neutral-600"
                in:fly={{ y: -10, duration: 200 }}
                out:fly={{ y: -10, duration: 200 }}
              >
                Saved
              </p>
            {/if}
          </div>
        {/snippet}
      </Form>
    </div>
  </SettingsLayout>
</AppLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/passwords/show.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import { fly } from "svelte/transition"

  import HeadingSmall from "@/components/heading-small.svelte"
  import InputError from "@/components/input-error.svelte"
  import { Button } from "@/components/ui/button"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import AppLayout from "@/layouts/app-layout.svelte"
  import SettingsLayout from "@/layouts/settings/layout.svelte"
  import { settingsPasswords } from "@/routes"
  import { type BreadcrumbItem } from "@/types"

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Password settings",
      href: settingsPasswords.show().url,
    },
  ]
</script>

<svelte:head>
  <title>{breadcrumbs[breadcrumbs.length - 1].title}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <SettingsLayout>
    <div class="space-y-6">
      <HeadingSmall
        title="Update password"
        description="Ensure your account is using a long, random password to stay secure"
      />

      <Form
        action={settingsPasswords.update()}
        options={{
          preserveScroll: true,
        }}
        resetOnError
        resetOnSuccess
        class="space-y-6"
      >
        {#snippet children({
          errors,
          processing,
          recentlySuccessful,
        }: FormComponentSlotProps)}
          <div class="grid gap-2">
            <Label for="password_challenge">Current password</Label>
            <Input
              id="password_challenge"
              name="password_challenge"
              type="password"
              class="mt-1 block w-full"
              autocomplete="current-password"
              placeholder="Current password"
            />
            <InputError messages={errors.password_challenge} />
          </div>

          <div class="grid gap-2">
            <Label for="password">New password</Label>
            <Input
              id="password"
              name="password"
              type="password"
              class="mt-1 block w-full"
              autocomplete="new-password"
              placeholder="New password"
            />
            <InputError messages={errors.password} />
          </div>

          <div class="grid gap-2">
            <Label for="password_confirmation">Confirm password</Label>
            <Input
              id="password_confirmation"
              name="password_confirmation"
              type="password"
              class="mt-1 block w-full"
              autocomplete="new-password"
              placeholder="Confirm password"
            />
            <InputError messages={errors.password_confirmation} />
          </div>

          <div class="flex items-center gap-4">
            <Button type="submit" disabled={processing}>Save password</Button>

            {#if recentlySuccessful}
              <p
                class="text-sm text-neutral-600"
                in:fly={{ y: -10, duration: 200 }}
                out:fly={{ y: -10, duration: 200 }}
              >
                Saved.
              </p>
            {/if}
          </div>
        {/snippet}
      </Form>
    </div>
  </SettingsLayout>
</AppLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/profiles/show.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form, page } from "@inertiajs/svelte"
  import { fly } from "svelte/transition"

  import DeleteUser from "@/components/delete-user.svelte"
  import HeadingSmall from "@/components/heading-small.svelte"
  import InputError from "@/components/input-error.svelte"
  import { Button } from "@/components/ui/button"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import AppLayout from "@/layouts/app-layout.svelte"
  import SettingsLayout from "@/layouts/settings/layout.svelte"
  import { settingsProfiles } from "@/routes"
  import { type BreadcrumbItem } from "@/types"

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Profile settings",
      href: settingsProfiles.show().url,
    },
  ]
</script>

<svelte:head>
  <title>{breadcrumbs[breadcrumbs.length - 1].title}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <SettingsLayout>
    <div class="flex flex-col space-y-6">
      <HeadingSmall
        title="Profile information"
        description="Update your name and email address"
      />

      <Form
        action={settingsProfiles.update()}
        options={{
          preserveScroll: true,
        }}
        class="space-y-6"
      >
        {#snippet children({
          errors,
          processing,
          recentlySuccessful,
        }: FormComponentSlotProps)}
          <div class="grid gap-2">
            <Label for="name">Name</Label>
            <Input
              id="name"
              name="name"
              class="mt-1 block w-full"
              value={page.props.auth.user.name}
              required
              autocomplete="name"
              placeholder="Full name"
            />
            <InputError class="mt-2" messages={errors.name} />
          </div>

          <div class="flex items-center gap-4">
            <Button type="submit" disabled={processing}>Save</Button>

            {#if recentlySuccessful}
              <p
                class="text-sm text-neutral-600"
                in:fly={{ y: -10, duration: 200 }}
                out:fly={{ y: -10, duration: 200 }}
              >
                Saved.
              </p>
            {/if}
          </div>
        {/snippet}
      </Form>
    </div>

    <DeleteUser />
  </SettingsLayout>
</AppLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/settings/sessions/index.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import { router } from "@inertiajs/svelte"
  import { page } from "@inertiajs/svelte"

  import HeadingSmall from "@/components/heading-small.svelte"
  import { Badge } from "@/components/ui/badge"
  import { Button } from "@/components/ui/button"
  import AppLayout from "@/layouts/app-layout.svelte"
  import SettingsLayout from "@/layouts/settings/layout.svelte"
  import { sessions as sessionsRoutes, settingsSessions } from "@/routes"
  import type { BreadcrumbItem, Session } from "@/types"

  interface Props {
    sessions: Session[]
  }

  let { sessions }: Props = $props()

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Sessions",
      href: settingsSessions.index().url,
    },
  ]

  const auth = $derived(page.props.auth)

  const deleteSession = (sessionId: number) => {
    router.delete(sessionsRoutes.destroy(sessionId).url)
  }
</script>

<svelte:head>
  <title>{breadcrumbs[breadcrumbs.length - 1].title}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <SettingsLayout>
    <div class="space-y-6">
      <HeadingSmall
        title="Sessions"
        description="Manage your active sessions across devices"
      />
      <div class="space-y-4">
        {#each sessions as session (session.id)}
          <div class="flex flex-col space-y-2 rounded-lg border p-4">
            <div class="flex items-center justify-between">
              <div class="space-y-1">
                <p class="font-medium">
                  {session.user_agent}
                  {#if session.id === auth.session.id}
                    <Badge variant="secondary" class="ml-2">Current</Badge>
                  {/if}
                </p>
                <p class="text-muted-foreground text-sm">
                  IP: {session.ip_address}
                </p>
                <p class="text-muted-foreground text-sm">
                  Active since:
                  {new Date(session.created_at).toLocaleString()}
                </p>
              </div>
              {#if session.id !== auth.session.id}
                <Button
                  variant="destructive"
                  onclick={() => deleteSession(session.id)}
                >
                  Log out
                </Button>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    </div>
  </SettingsLayout>
</AppLayout>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/pages/users/new.svelte", ERB.new(
    *[
  <<~'TCODE'
<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import { LoaderCircle } from "@lucide/svelte"

  import InputError from "@/components/input-error.svelte"
  import TextLink from "@/components/text-link.svelte"
  import { Button } from "@/components/ui/button"
  import { Input } from "@/components/ui/input"
  import { Label } from "@/components/ui/label"
  import AuthBase from "@/layouts/auth-layout.svelte"
  import { sessions, users } from "@/routes"
</script>

<svelte:head>
  <title>Register</title>
</svelte:head>

<AuthBase
  title="Create an account"
  description="Enter your details below to create your account"
>
  <Form
    action={users.create()}
    resetOnSuccess={["password", "password_confirmation"]}
    disableWhileProcessing
    class="flex flex-col gap-6"
  >
    {#snippet children({ errors, processing }: FormComponentSlotProps)}
      <div class="grid gap-6">
        <div class="grid gap-2">
          <Label for="name">Name</Label>
          <Input
            id="name"
            name="name"
            type="text"
            required
            autofocus
            tabindex={1}
            autocomplete="name"
            placeholder="Full name"
          />
          <InputError messages={errors.name} />
        </div>

        <div class="grid gap-2">
          <Label for="email">Email address</Label>
          <Input
            id="email"
            name="email"
            type="email"
            required
            tabindex={2}
            autocomplete="email"
            placeholder="email@example.com"
          />
          <InputError messages={errors.email} />
        </div>

        <div class="grid gap-2">
          <Label for="password">Password</Label>
          <Input
            id="password"
            name="password"
            type="password"
            required
            tabindex={3}
            autocomplete="new-password"
            placeholder="Password"
          />
          <InputError messages={errors.password} />
        </div>

        <div class="grid gap-2">
          <Label for="password_confirmation">Confirm password</Label>
          <Input
            id="password_confirmation"
            name="password_confirmation"
            type="password"
            required
            tabindex={4}
            autocomplete="new-password"
            placeholder="Confirm password"
          />
          <InputError messages={errors.password_confirmation} />
        </div>

        <Button
          type="submit"
          class="mt-2 w-full"
          tabindex={5}
          disabled={processing}
        >
          {#if processing}
            <LoaderCircle class="h-4 w-4 animate-spin" />
          {/if}
          Create account
        </Button>
      </div>

      <div class="text-muted-foreground text-center text-sm">
        Already have an account?
        <TextLink
          href={sessions.new()}
          class="underline underline-offset-4"
          tabindex={6}>Log in</TextLink
        >
      </div>
    {/snippet}
  </Form>
</AuthBase>
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/runes/use-appearance.svelte.ts", ERB.new(
    *[
  <<~'TCODE'
import { isBrowser } from "@/lib/browser"
import * as storage from "@/lib/storage"

type Appearance = "light" | "dark" | "system"

const prefersDark = () => {
  if (!isBrowser) {
    return false
  }
  return window.matchMedia("(prefers-color-scheme: dark)").matches
}

const applyTheme = (appearance: Appearance) => {
  if (!isBrowser) return

  const isDark =
    appearance === "dark" || (appearance === "system" && prefersDark())

  document.documentElement.classList.toggle("dark", isDark)
}

const mediaQuery = () => {
  if (!isBrowser) {
    return null
  }

  return window.matchMedia("(prefers-color-scheme: dark)")
}

const handleSystemThemeChange = () => {
  const currentAppearance = storage.getItem("appearance") as Appearance
  applyTheme(currentAppearance ?? "system")
}

export function initializeTheme() {
  const savedAppearance =
    (storage.getItem("appearance") as Appearance) || "system"

  applyTheme(savedAppearance)

  mediaQuery()?.addEventListener("change", handleSystemThemeChange)
}

export function useAppearanceSvelte() {
  let appearance = $state<Appearance>("system")

  $effect.pre(() => {
    const savedAppearance = storage.getItem("appearance") as Appearance | null

    if (savedAppearance) {
      appearance = savedAppearance
    }
  })

  const update = (value: Appearance) => {
    appearance = value

    if (value === "system") {
      storage.removeItem("appearance")
    } else {
      storage.setItem("appearance", value)
    }
    applyTheme(value)
  }

  return {
    get value() {
      return appearance
    },
    update,
  }
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/runes/use-flash.svelte.ts", ERB.new(
    *[
  <<~'TCODE'
import { router } from "@inertiajs/svelte"
import { toast } from "svelte-sonner"

export function useFlash() {
  $effect(() => {
    return router.on("flash", (event) => {
      const flash = event.detail.flash
      if (flash.alert) {
        toast.error(flash.alert)
      }
      if (flash.notice) {
        toast(flash.notice)
      }
    })
  })
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/runes/use-initials.ts", ERB.new(
    *[
  <<~'TCODE'
export function getInitials(fullName?: string): string {
  if (!fullName) return ""

  const names = fullName.trim().split(" ")

  if (names.length === 0) return ""
  if (names.length === 1) return names[0].charAt(0).toUpperCase()

  return `${names[0].charAt(0)}${names[names.length - 1].charAt(0)}`.toUpperCase()
}

export function useInitials() {
  return { getInitials }
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/types/index.ts", ERB.new(
    *[
  <<~'TCODE'
import type { Component } from "svelte"

export interface Auth {
  user: User
  session: Pick<Session, "id">
}

export interface BreadcrumbItem {
  title: string
  href: string
}

export interface NavItem {
  title: string
  href: string
  icon?: Component
  isActive?: boolean
}

export interface FlashData {
  alert?: string
  notice?: string
}

export interface SharedProps {
  auth: Auth
}

export interface User {
  id: number
  name: string
  email: string
  avatar?: string
  verified: boolean
  created_at: string
  updated_at: string
}

export type BreadcrumbItemType = BreadcrumbItem

export interface Session {
  id: number
  user_agent: string
  ip_address: string
  created_at: string
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "#{js_destination_path}/utils.ts", ERB.new(
    *[
  <<~'TCODE'
import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type WithoutChild<T> = T extends { child?: any } ? Omit<T, "child"> : T
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type WithoutChildren<T> = T extends { children?: any }
  ? Omit<T, "children">
  : T
export type WithoutChildrenOrChild<T> = WithoutChildren<WithoutChild<T>>
export type WithElementRef<T, U extends HTMLElement = HTMLElement> = T & {
  ref?: U | null
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true  end

  say "  Starter Kit frontend configured ✓", :green
end

# ─── Phase 6: Optional Tools ──────────────────────────────────────

# ─── Alba ─────────────────────────────────────────────────────────────

if use_alba
  say use_typescript ? "📦 Setting up typed serializers (Alba + Typelizer)..." : "📦 Setting up serializers (Alba)...", :cyan

  gems_to_add.push("alba", "alba-inertia")

  # When TypeScript is on, Typelizer generates types from serializers
  if use_typescript
    add_gem.("typelizer")
  end

  file "config/initializers/alba.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

Alba.backend = :active_support
Alba.inflector = :active_support
  TCODE
  ], trim_mode: "<>").result(binding)

  file "app/serializers/application_serializer.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class ApplicationSerializer
  include Alba::Resource

<% if use_typescript %>
  helper Typelizer::DSL
<% end %>
  helper Alba::Inertia::Resource

  include Rails.application.routes.url_helpers
end
  TCODE
  ], trim_mode: "<>").result(binding)

  gsub_file "app/controllers/inertia_controller.rb",
    /class InertiaController.*\n/,
    '\0' + "  include Alba::Inertia::Controller\n"

  if use_typescript
    # When starter kit + typelizer: remove hand-written types that typelizer generates,
    # and re-export from typelizer's serializers barrel instead.
    types_index = "#{js_destination_path}/types/index.ts"
    if use_starter_kit && File.exist?(types_index)
      gsub_file types_index, /^export interface (Auth|User|Session|SharedProps) \{[^}]*\}\n\n?/m, ""
      append_with_blank_line.(types_index, "export * from \"./serializers\"\n")
    end

    eslint_ignores << "types/serializers/**"
  end

  say use_typescript ? "  Typed serializers configured ✓" : "  Serializers configured ✓", :green
end
# ─── Test Framework ───────────────────────────────────────────────────

if test_framework == "rspec"
  say "📦 Setting up RSpec...", :cyan

  gems_to_add << {name: "rspec-rails", group: %i[development test]}

  say "  RSpec will be installed ✓", :green
end

if use_starter_kit
  say "📦 Setting up starter kit tests (#{test_framework})...", :cyan

  # ─── Fixtures (shared between minitest and rspec) ────────────────
    file "test/fixtures/users.yml", ERB.new(
    *[
  <<~'TCODE'
# Password for both users is: Secret1*3*5*
one:
  email: one@example.com
  name: Test User
  password_digest: "$2a$04$FPZVbthSpWD4rXvKNiNgzOVDQ3W4ozJjvtr59iUo6hWHCyAiiM9AO"
  verified: true

two:
  email: two@example.com
  name: Another User
  password_digest: "$2a$04$FPZVbthSpWD4rXvKNiNgzOVDQ3W4ozJjvtr59iUo6hWHCyAiiM9AO"
  verified: true
  TCODE
  ], trim_mode: "<>").result(binding), force: true
  # ─── Minitest files ──────────────────────────────────────────────
  if test_framework == "minitest"
    file "test/controllers/identity/email_verifications_controller_test.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "test_helper"

class Identity::EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "verifies email with valid token" do
    user = users(:one)
    user.update!(verified: false)
    sid = user.generate_token_for(:email_verification)

    get identity_email_verification_path(sid: sid)
    assert_redirected_to root_path

    assert user.reload.verified?
  end

  test "rejects invalid verification token" do
    get identity_email_verification_path(sid: "invalid")
    assert_redirected_to settings_email_path
  end

  test "resends verification email" do
    sign_in users(:one)

    assert_enqueued_emails 1 do
      post identity_email_verification_path
    end
    assert_response :redirect
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "test/controllers/identity/password_resets_controller_test.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "test_helper"

class Identity::PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "renders forgot password page" do
    get new_identity_password_reset_path
    assert_response :success
  end

  test "sends password reset email for verified user" do
    assert_enqueued_emails 1 do
      post identity_password_reset_path, params: { email: users(:one).email }
    end
    assert_redirected_to sign_in_path
  end

  test "rejects password reset for unverified user" do
    users(:one).update!(verified: false)
    assert_no_enqueued_emails do
      post identity_password_reset_path, params: { email: users(:one).email }
    end
    assert_redirected_to new_identity_password_reset_path
  end

  test "renders password reset edit page" do
    sid = users(:one).generate_token_for(:password_reset)
    get edit_identity_password_reset_path(sid: sid)
    assert_response :success
  end

  test "rejects invalid reset token" do
    get edit_identity_password_reset_path(sid: "invalid")
    assert_redirected_to new_identity_password_reset_path
  end

  test "updates password with valid token" do
    sid = users(:one).generate_token_for(:password_reset)
    patch identity_password_reset_path(sid: sid), params: {
      password: "NewPassword1*3*",
      password_confirmation: "NewPassword1*3*"
    }
    assert_redirected_to sign_in_path
  end

  test "rejects mismatched password confirmation" do
    sid = users(:one).generate_token_for(:password_reset)
    patch identity_password_reset_path(sid: sid), params: {
      password: "NewPassword1*3*",
      password_confirmation: "different"
    }
    assert_redirected_to edit_identity_password_reset_path(sid: sid)
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "test/controllers/sessions_controller_test.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "renders sign in page" do
    get sign_in_path
    assert_response :success
  end

  test "redirects authenticated users away from sign in" do
    sign_in users(:one)
    get sign_in_path
    assert_redirected_to root_path
  end

  test "signs in with valid credentials" do
    post sign_in_path, params: { email: users(:one).email, password: "Secret1*3*5*" }
    assert_redirected_to dashboard_path
    assert cookies[:session_token].present?
  end

  test "rejects invalid credentials" do
    post sign_in_path, params: { email: users(:one).email, password: "wrongpassword" }
    assert_redirected_to sign_in_path
  end

  test "destroys a session" do
    sign_in users(:one)
    session_record = users(:one).sessions.last
    delete session_path(session_record)
    assert_redirected_to settings_sessions_path
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "test/controllers/settings/emails_controller_test.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "test_helper"

class Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    sign_in users(:one)
  end

  test "renders email settings page" do
    get settings_email_path
    assert_response :success
  end

  test "updates email with valid password" do
    patch settings_email_path, params: {
      email: "updated@example.com",
      password_challenge: "Secret1*3*5*"
    }
    assert_redirected_to settings_email_path
    assert_equal "updated@example.com", users(:one).reload.email
  end

  test "rejects email update with wrong password" do
    patch settings_email_path, params: {
      email: "updated@example.com",
      password_challenge: "wrongpassword"
    }
    assert_redirected_to settings_email_path
    assert_equal "one@example.com", users(:one).reload.email
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "test/controllers/settings/passwords_controller_test.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "test_helper"

class Settings::PasswordsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    sign_in users(:one)
  end

  test "renders password settings page" do
    get settings_password_path
    assert_response :success
  end

  test "updates password with valid current password" do
    patch settings_password_path, params: {
      password: "NewPassword1*3*",
      password_confirmation: "NewPassword1*3*",
      password_challenge: "Secret1*3*5*"
    }
    assert_redirected_to settings_password_path
  end

  test "rejects password update with wrong current password" do
    patch settings_password_path, params: {
      password: "NewPassword1*3*",
      password_confirmation: "NewPassword1*3*",
      password_challenge: "wrongpassword"
    }
    assert_redirected_to settings_password_path
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "test/controllers/settings/sessions_controller_test.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "test_helper"

class Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    sign_in users(:one)
  end

  test "renders sessions index" do
    get settings_sessions_path
    assert_response :success
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "test/controllers/users_controller_test.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "renders sign up page" do
    get sign_up_path
    assert_response :success
  end

  test "redirects authenticated users away from sign up" do
    sign_in users(:one)
    get sign_up_path
    assert_redirected_to root_path
  end

  test "creates a new user" do
    assert_difference "User.count", 1 do
      post sign_up_path, params: {
        name: "New User",
        email: "new@example.com",
        password: "Secret1*3*5*",
        password_confirmation: "Secret1*3*5*"
      }
    end
    assert_redirected_to dashboard_path
  end

  test "rejects invalid user" do
    assert_no_difference "User.count" do
      post sign_up_path, params: {
        name: "",
        email: "invalid",
        password: "short",
        password_confirmation: "short"
      }
    end
    assert_redirected_to sign_up_path
  end

  test "destroys current user with valid password" do
    sign_in users(:one)
    assert_difference "User.count", -1 do
      delete users_path, params: { password_challenge: "Secret1*3*5*" }
    end
    assert_redirected_to root_path
  end

  test "rejects account deletion with wrong password" do
    sign_in users(:one)
    assert_no_difference "User.count" do
      delete users_path, params: { password_challenge: "wrongpassword" }
    end
    assert_redirected_to settings_profile_path
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "test/mailers/user_mailer_test.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  fixtures :users

  test "email_verification" do
    mail = UserMailer.with(user: users(:one)).email_verification
    assert_equal "Verify your email", mail.subject
    assert_equal [ "one@example.com" ], mail.to
  end

  test "password_reset" do
    mail = UserMailer.with(user: users(:one)).password_reset
    assert_equal "Reset your password", mail.subject
    assert_equal [ "one@example.com" ], mail.to
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "test/test_helpers/session_test_helper.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

module SessionTestHelper
  def self.signed_cookie(name, value)
    cookie_jar = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
    cookie_jar.signed[name] = value
    cookie_jar[name]
  end

  def sign_in(user)
    session = user.sessions.create!
    cookies[:session_token] = SessionTestHelper.signed_cookie(:session_token, session.id)
  end

  def sign_out
    cookies[:session_token] = ""
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    # Add session helper require to test_helper.rb
    if File.exist?("test/test_helper.rb")
      insert_into_file "test/test_helper.rb",
        "\nrequire_relative \"test_helpers/session_test_helper\"\n",
        after: "require \"rails/test_help\"\n"

      insert_into_file "test/test_helper.rb",
        "\nclass ActiveSupport::TestCase\n  include SessionTestHelper\nend\n",
        before: /\z/
    end

    say "  Minitest files created ✓", :green
  end

  # ─── RSpec files ─────────────────────────────────────────────────
  if test_framework == "rspec"
    file ".rspec", "--require spec_helper\n", force: true
    file "spec/mailers/user_mailer_spec.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  fixtures :users

  describe "email_verification" do
    let(:mail) { described_class.with(user: users(:one)).email_verification }

    it "sends to the user's email" do
      expect(mail.to).to eq([ "one@example.com" ])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("Verify your email")
    end
  end

  describe "password_reset" do
    let(:mail) { described_class.with(user: users(:one)).password_reset }

    it "sends to the user's email" do
      expect(mail.to).to eq([ "one@example.com" ])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("Reset your password")
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/rails_helper.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end


RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("test/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include ActiveSupport::Testing::TimeHelpers
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/requests/identity/email_verifications_spec.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Identity::EmailVerifications", type: :request do
  fixtures :users

  describe "GET /identity/email_verification" do
    context "with valid token" do
      it "verifies the email" do
        user = users(:one)
        user.update!(verified: false)
        sid = user.generate_token_for(:email_verification)

        get identity_email_verification_path(sid: sid)
        expect(response).to redirect_to(root_path)
        expect(user.reload).to be_verified
      end
    end

    context "with expired token" do
      it "does not verify the email" do
        user = users(:one)
        user.update!(verified: false)
        sid = user.generate_token_for(:email_verification)

        travel 3.days

        get identity_email_verification_path(sid: sid)
        expect(response).to redirect_to(settings_email_path)
        expect(flash[:alert]).to eq("That email verification link is invalid")
        expect(user.reload).not_to be_verified
      end
    end

    context "with invalid token" do
      it "redirects to settings email" do
        get identity_email_verification_path(sid: "invalid")
        expect(response).to redirect_to(settings_email_path)
      end
    end
  end

  describe "POST /identity/email_verification" do
    it "resends the verification email" do
      sign_in users(:one)

      expect {
        post identity_email_verification_path
      }.to have_enqueued_mail(UserMailer, :email_verification)
      expect(response).to be_redirect
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/requests/identity/password_resets_spec.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Identity::PasswordResets", type: :request do
  fixtures :users

  describe "GET /identity/password_reset/new" do
    it "renders the forgot password page" do
      get new_identity_password_reset_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /identity/password_reset" do
    context "with a verified user" do
      it "sends a password reset email" do
        expect {
          post identity_password_reset_path, params: { email: users(:one).email }
        }.to have_enqueued_mail(UserMailer, :password_reset)
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "with an unverified user" do
      it "does not send a password reset email" do
        users(:one).update!(verified: false)

        expect {
          post identity_password_reset_path, params: { email: users(:one).email }
        }.not_to have_enqueued_mail(UserMailer, :password_reset)
        expect(response).to redirect_to(new_identity_password_reset_path)
        expect(flash[:alert]).to eq("You can't reset your password until you verify your email")
      end
    end

    context "with a nonexistent email" do
      it "does not send a password reset email" do
        expect {
          post identity_password_reset_path, params: { email: "missing@example.com" }
        }.not_to have_enqueued_mail(UserMailer, :password_reset)
        expect(response).to redirect_to(new_identity_password_reset_path)
      end
    end
  end

  describe "GET /identity/password_reset/edit" do
    it "renders the reset page with valid token" do
      sid = users(:one).generate_token_for(:password_reset)
      get edit_identity_password_reset_path(sid: sid)
      expect(response).to have_http_status(:success)
    end

    it "rejects invalid reset token" do
      get edit_identity_password_reset_path(sid: "invalid")
      expect(response).to redirect_to(new_identity_password_reset_path)
    end
  end

  describe "PATCH /identity/password_reset" do
    context "with valid token" do
      it "updates the password" do
        sid = users(:one).generate_token_for(:password_reset)
        patch identity_password_reset_path(sid: sid), params: {
          password: "NewPassword1*3*",
          password_confirmation: "NewPassword1*3*"
        }
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "with expired token" do
      it "rejects the password change" do
        sid = users(:one).generate_token_for(:password_reset)
        travel 30.minutes

        patch identity_password_reset_path(sid: sid), params: {
          password: "NewPassword1*3*",
          password_confirmation: "NewPassword1*3*"
        }
        expect(response).to redirect_to(new_identity_password_reset_path)
        expect(flash[:alert]).to eq("That password reset link is invalid")
      end
    end

    context "with mismatched password confirmation" do
      it "rejects the password change" do
        sid = users(:one).generate_token_for(:password_reset)
        patch identity_password_reset_path(sid: sid), params: {
          password: "NewPassword1*3*",
          password_confirmation: "different"
        }
        expect(response).to redirect_to(edit_identity_password_reset_path(sid: sid))
      end
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/requests/sessions_spec.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  fixtures :users

  describe "GET /sign_in" do
    it "renders the sign in page" do
      get sign_in_path
      expect(response).to have_http_status(:success)
    end

    it "redirects authenticated users" do
      sign_in users(:one)
      get sign_in_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /sign_in" do
    context "with valid credentials" do
      it "signs in and sets a session cookie" do
        post sign_in_path, params: { email: users(:one).email, password: "Secret1*3*5*" }
        expect(response).to redirect_to(dashboard_path)
        expect(cookies[:session_token]).to be_present
      end
    end

    context "with invalid credentials" do
      it "redirects back with an alert" do
        post sign_in_path, params: { email: users(:one).email, password: "wrongpassword" }
        expect(response).to redirect_to(sign_in_path)
        expect(flash[:alert]).to eq("That email or password is incorrect")
      end
    end
  end

  describe "DELETE /sessions/:id" do
    it "destroys the session" do
      sign_in users(:one)
      session_record = users(:one).sessions.last
      delete session_path(session_record)
      expect(response).to redirect_to(settings_sessions_path)
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/requests/settings/emails_spec.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings::Emails", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /settings/email" do
    it "renders the email settings page" do
      get settings_email_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /settings/email" do
    context "with valid password challenge" do
      it "updates the email" do
        patch settings_email_path, params: {
          email: "updated@example.com",
          password_challenge: "Secret1*3*5*"
        }
        expect(response).to redirect_to(settings_email_path)
        expect(flash[:notice]).to eq("Your email has been changed")
        expect(users(:one).reload.email).to eq("updated@example.com")
      end
    end

    context "with invalid password challenge" do
      it "does not update the email and returns inertia errors" do
        patch settings_email_path, params: {
          email: "updated@example.com",
          password_challenge: "wrongpassword"
        }
        expect(response).to redirect_to(settings_email_path)
        expect(session[:inertia_errors]).to eq(password_challenge: ["is invalid"])
        expect(users(:one).reload.email).to eq("one@example.com")
      end
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/requests/settings/passwords_spec.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings::Passwords", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /settings/password" do
    it "renders the password settings page" do
      get settings_password_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /settings/password" do
    context "with valid password challenge" do
      it "updates the password" do
        patch settings_password_path, params: {
          password: "NewPassword1*3*",
          password_confirmation: "NewPassword1*3*",
          password_challenge: "Secret1*3*5*"
        }
        expect(response).to redirect_to(settings_password_path)
        expect(flash[:notice]).to eq("Your password has been changed")
      end
    end

    context "with invalid password challenge" do
      it "does not update the password and returns inertia errors" do
        patch settings_password_path, params: {
          password: "NewPassword1*3*",
          password_confirmation: "NewPassword1*3*",
          password_challenge: "wrongpassword"
        }
        expect(response).to redirect_to(settings_password_path)
        expect(session[:inertia_errors]).to eq(password_challenge: ["is invalid"])
      end
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/requests/settings/sessions_spec.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings::Sessions", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /settings/sessions" do
    it "renders the sessions index" do
      get settings_sessions_path
      expect(response).to have_http_status(:success)
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/requests/users_spec.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users", type: :request do
  fixtures :users

  describe "GET /sign_up" do
    it "renders the sign up page" do
      get sign_up_path
      expect(response).to have_http_status(:success)
    end

    it "redirects authenticated users" do
      sign_in users(:one)
      get sign_up_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /sign_up" do
    it "creates a new user" do
      expect {
        post sign_up_path, params: {
          name: "New User",
          email: "new@example.com",
          password: "Secret1*3*5*",
          password_confirmation: "Secret1*3*5*"
        }
      }.to change(User, :count).by(1)
      expect(response).to redirect_to(dashboard_path)
    end

    it "rejects invalid user" do
      expect {
        post sign_up_path, params: {
          name: "",
          email: "invalid",
          password: "short",
          password_confirmation: "short"
        }
      }.not_to change(User, :count)
      expect(response).to redirect_to(sign_up_path)
    end
  end

  describe "DELETE /users" do
    it "destroys current user with valid password" do
      sign_in users(:one)
      expect {
        delete users_path, params: { password_challenge: "Secret1*3*5*" }
      }.to change(User, :count).by(-1)
      expect(response).to redirect_to(root_path)
    end

    it "rejects account deletion with wrong password" do
      sign_in users(:one)
      expect {
        delete users_path, params: { password_challenge: "wrongpassword" }
      }.not_to change(User, :count)
      expect(response).to redirect_to(settings_profile_path)
    end
  end
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/spec_helper.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus

  config.example_status_persistence_file_path = "tmp/examples.txt"

  config.disable_monkey_patching!

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.profile_examples = 10 if ENV["PROFILE"]

  config.order = :random
  Kernel.srand config.seed
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    file "spec/support/authentication_helpers.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

module AuthenticationHelpers
  def self.signed_cookie(name, value)
    cookie_jar = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
    cookie_jar.signed[name] = value
    cookie_jar[name]
  end

  def sign_in(user)
    session = user.sessions.create!
    cookies[:session_token] = AuthenticationHelpers.signed_cookie(:session_token, session.id)
  end

  def sign_out
    cookies[:session_token] = ""
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    # Remove Rails-scaffolded minitest structure (keep test/fixtures for rspec to read)
    %w[
      test/test_helper.rb
      test/channels
      test/controllers
      test/helpers
      test/integration
      test/mailers
      test/models
    ].each { |path| remove_file path }

    say "  RSpec files created ✓", :green
  end
end
# ─── ESLint + Prettier ───────────────────────────────────────────────

if use_eslint
  say "📦 Setting up ESLint + Prettier...", :cyan

  # Common dev packages (all frameworks)
  npm_dev_packages.push("prettier", "eslint@9", "eslint-plugin-import")

  if use_typescript
    npm_dev_packages << "eslint-import-resolver-typescript"
  end

  # Framework-specific packages + config
  case framework
  when "react"
    npm_dev_packages.push("@eslint/js@9", "eslint-config-prettier", "globals", "eslint-plugin-react", "eslint-plugin-react-hooks")
    npm_dev_packages << "typescript-eslint" if use_typescript
    file "eslint.config.js", ERB.new(
    *[
  <<~'TCODE'
<% if use_typescript %>
import pluginJs from "@eslint/js"
import prettierConfig from "eslint-config-prettier/flat"
import importPlugin from "eslint-plugin-import"
import pluginReact from "eslint-plugin-react"
import reactHooks from "eslint-plugin-react-hooks"
import globals from "globals"
import tseslint from "typescript-eslint"

/** @type {import('eslint').Linter.Config[]} */
export default [
  { files: ["<%= js_destination_path %>/**/*.{js,mjs,cjs,ts,jsx,tsx}"] },
  { ignores: [<%= eslint_ignores.map { |i| "\"#{js_destination_path}/#{i}\"" }.join(", ") %>] },
  {
    settings: {
      react: {
        version: "detect",
      },
    },
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  pluginJs.configs.recommended,
  reactHooks.configs.flat.recommended,
  ...tseslint.configs.stylisticTypeChecked,
  ...tseslint.configs.recommendedTypeChecked,
  pluginReact.configs.flat.recommended,
  pluginReact.configs.flat["jsx-runtime"],
  prettierConfig,
  {
    ...importPlugin.flatConfigs.recommended,
    ...importPlugin.flatConfigs.typescript,
    ...importPlugin.flatConfigs.react,
    settings: { "import/resolver": { typescript: {} } },
    rules: {
      "import/order": [
        "error",
        {
          pathGroups: [
            {
              pattern: "@/**",
              group: "external",
              position: "after",
            },
          ],
          "newlines-between": "always",
          named: true,
          alphabetize: { order: "asc" },
        },
      ],
      "import/first": "error",
      "import/extensions": [
        "error",
        "always",
        {
          js: "never",
          jsx: "never",
          ts: "never",
          tsx: "never",
        },
      ],
      "@typescript-eslint/consistent-type-imports": "error",
      "react/prop-types": "off",
    },
  },
  {
    files: ["**/*.js"],
    ...tseslint.configs.disableTypeChecked,
  },
]
<% else %>
import pluginJs from "@eslint/js"
import prettierConfig from "eslint-config-prettier/flat"
import importPlugin from "eslint-plugin-import"
import pluginReact from "eslint-plugin-react"
import reactHooks from "eslint-plugin-react-hooks"
import globals from "globals"

/** @type {import('eslint').Linter.Config[]} */
export default [
  { files: ["<%= js_destination_path %>/**/*.{js,mjs,cjs,jsx}"] },
  { ignores: [<%= eslint_ignores.map { |i| "\"#{js_destination_path}/#{i}\"" }.join(", ") %>] },
  {
    settings: {
      react: {
        version: "detect",
      },
    },
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
  },
  pluginJs.configs.recommended,
  reactHooks.configs.flat.recommended,
  pluginReact.configs.flat.recommended,
  pluginReact.configs.flat["jsx-runtime"],
  prettierConfig,
  {
    ...importPlugin.flatConfigs.recommended,
    ...importPlugin.flatConfigs.react,
    rules: {
      "react/prop-types": "off",
      "import/order": [
        "error",
        {
          "newlines-between": "always",
          named: true,
          alphabetize: { order: "asc" },
        },
      ],
      "import/first": "error",
      "react/prop-types": "off",
    },
  },
]
<% end %>
  TCODE
  ], trim_mode: "<>").result(binding)
  when "svelte"
    npm_dev_packages.push("@eslint/js@9", "eslint-config-prettier", "globals", "eslint-plugin-svelte")
    npm_dev_packages << "typescript-eslint" if use_typescript
    file "eslint.config.js", ERB.new(
    *[
  <<~'TCODE'
<% if use_typescript %>
import js from '@eslint/js'
import svelte from 'eslint-plugin-svelte'
import globals from 'globals'
import ts from 'typescript-eslint'
// eslint-disable-next-line import/extensions
import svelteConfig from './svelte.config.js'
import eslintConfigPrettier from "eslint-config-prettier/flat"
import importPlugin from "eslint-plugin-import"

export default ts.config(
  js.configs.recommended,
  ...ts.configs.recommended,
  ...svelte.configs.recommended,
  { ignores: [<%= eslint_ignores.map { |i| "\"#{js_destination_path}/#{i}\"" }.join(", ") %>] },
  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node
      }
    }
  },
  {
    files: ['**/*.svelte', '**/*.svelte.ts', '**/*.svelte.js'],
    languageOptions: {
      parserOptions: {
        projectService: true,
        extraFileExtensions: ['.svelte'],
        parser: ts.parser,
        svelteConfig
      }
    }
  },
  {
    ...importPlugin.flatConfigs.recommended,
    ...importPlugin.flatConfigs.typescript,
    settings: { "import/resolver": { typescript: {} } },
    rules: {
      "import/order": [
        "error",
        {
          pathGroups: [
            {
              pattern: "@/**",
              group: "external",
              position: "after",
            },
          ],
          "newlines-between": "always",
          "named": true,
          alphabetize: { order: "asc" },
        },
      ],
      "import/first": "error",
      "import/extensions": [
        "error",
        "always",
        {
          js: "never",
          jsx: "never",
          ts: "never",
          tsx: "never",
        },
      ],
      "@typescript-eslint/consistent-type-imports": "error",
    },
  },
  eslintConfigPrettier,
)
<% else %>
import js from '@eslint/js'
import svelte from 'eslint-plugin-svelte'
import globals from 'globals'
// eslint-disable-next-line import/extensions
import svelteConfig from './svelte.config.js'
import eslintConfigPrettier from "eslint-config-prettier/flat"
import importPlugin from "eslint-plugin-import"

export default [
  js.configs.recommended,
  ...svelte.configs.recommended,
  { ignores: [<%= eslint_ignores.map { |i| "\"#{js_destination_path}/#{i}\"" }.join(", ") %>] },
  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node
      }
    }
  },
  {
    files: ['**/*.svelte', '**/*.svelte.js'],
    languageOptions: {
      parserOptions: {
        svelteConfig
      }
    }
  },
  {
    ...importPlugin.flatConfigs.recommended,
    languageOptions: {
      sourceType: "module",
    },
    rules: {
      "import/order": [
        "error",
        {
          "newlines-between": "always",
          "named": true,
          alphabetize: { order: "asc" },
        },
      ],
      "import/first": "error",
    },
  },
  eslintConfigPrettier,
]
<% end %>
  TCODE
  ], trim_mode: "<>").result(binding)
  when "vue"
    npm_dev_packages.push("@vue/eslint-config-prettier", "eslint-plugin-vue")
    npm_dev_packages << "@vue/eslint-config-typescript" if use_typescript
    file "eslint.config.js", ERB.new(
    *[
  <<~'TCODE'
<% if use_typescript %>
import skipFormatting from "@vue/eslint-config-prettier/skip-formatting"
import {
  defineConfigWithVueTs,
  vueTsConfigs,
} from "@vue/eslint-config-typescript"
import importPlugin from "eslint-plugin-import"
import pluginVue from "eslint-plugin-vue"

export default defineConfigWithVueTs(
  {
    name: "app/files-to-lint",
    files: ["<%= js_destination_path %>/**/*.{ts,mts,tsx,vue}"],
  },
  { ignores: [<%= eslint_ignores.map { |i| "\"#{js_destination_path}/#{i}\"" }.join(", ") %>] },

  pluginVue.configs["flat/essential"],
  vueTsConfigs.recommended,
  {
    ...importPlugin.flatConfigs.recommended,
    ...importPlugin.flatConfigs.typescript,
    settings: { "import/resolver": { typescript: {} } },
    rules: {
      "vue/multi-word-component-names": "off",
      "import/order": [
        "error",
        {
          pathGroups: [
            {
              pattern: "@/**",
              group: "external",
              position: "after",
            },
          ],
          "newlines-between": "always",
          named: true,
          alphabetize: { order: "asc" },
        },
      ],
      "import/first": "error",
      "import/extensions": [
        "error",
        "always",
        {
          js: "never",
          jsx: "never",
          ts: "never",
          tsx: "never",
          mts: "never",
        },
      ],
      "@typescript-eslint/consistent-type-imports": "error",
    },
  },
  skipFormatting,
)
<% else %>
import skipFormatting from "@vue/eslint-config-prettier/skip-formatting"
import importPlugin from "eslint-plugin-import"
import pluginVue from "eslint-plugin-vue"

export default [
  {
    name: "app/files-to-lint",
    files: ["<%= js_destination_path %>/**/*.{js,vue}"],
  },
  { ignores: [<%= eslint_ignores.map { |i| "\"#{js_destination_path}/#{i}\"" }.join(", ") %>] },

  ...pluginVue.configs["flat/essential"],
  {
    ...importPlugin.flatConfigs.recommended,
    languageOptions: {
      sourceType: "module",
    },
    rules: {
      "vue/multi-word-component-names": "off",
      "import/order": [
        "error",
        {
          "newlines-between": "always",
          named: true,
          alphabetize: { order: "asc" },
        },
      ],
      "import/first": "error",
    },
  },
  skipFormatting,
]
<% end %>
  TCODE
  ], trim_mode: "<>").result(binding)
  end

  # Prettier config
  if use_tailwind
    npm_dev_packages << "prettier-plugin-tailwindcss"
    file ".prettierrc", ERB.new(
    *[
  <<~'TCODE'
{
  "printWidth": 80,
  "semi": false,
  "tabWidth": 2,
  "trailingComma": "all",
  "plugins": [
    "prettier-plugin-tailwindcss"
  ],
  "tailwindFunctions": [
    "clsx",
    "cn"
  ]
}
  TCODE
  ], trim_mode: "<>").result(binding)
  else
    file ".prettierrc", ERB.new(
    *[
  <<~'TCODE'
{
  "printWidth": 80,
  "semi": false,
  "tabWidth": 2,
  "trailingComma": "all"
}
  TCODE
  ], trim_mode: "<>").result(binding)
  end

  # .prettierignore
  file ".prettierignore", <<~TXT
    build
    coverage
    #{js_destination_path}/routes
  TXT

  # Add lint scripts to package.json
  root_files = "'*.{js,mjs,cjs,ts}'"
  update_package_json.call { |pkg|
    pkg["scripts"] ||= {}
    pkg["scripts"]["lint"] = "eslint #{root_files} #{js_destination_path}/ --report-unused-disable-directives --max-warnings 0"
    pkg["scripts"]["lint:fix"] = "eslint #{root_files} #{js_destination_path}/ --fix"
    pkg["scripts"]["format"] = "prettier --check '#{js_destination_path}' #{root_files}"
    pkg["scripts"]["format:fix"] = "prettier --write '#{js_destination_path}' #{root_files}"
  }

  say "  ESLint + Prettier configured ✓", :green
end

# ─── Phase 7: Deploy + Finalize ───────────────────────────────────────

# ─── Welcome Page ────────────────────────────────────────────────────

# Skip example page if starter kit provides its own pages
unless use_starter_kit
  say "📦 Creating welcome page...", :cyan

  file "app/controllers/home_controller.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

class HomeController < InertiaController
  def index
    render inertia: {
      rails_version: Rails.version,
      ruby_version: RUBY_DESCRIPTION,
      inertia_rails_version: InertiaRails::VERSION
    }
  end
end
  TCODE
  ], trim_mode: "<>").result(binding)

  routes_content = File.read("config/routes.rb")
  unless routes_content.match?(/^\s*root\s+/)
    route 'root "home#index"'
  end

  case framework
  when "react"
    file "#{js_destination_path}/pages/home/index.#{component_ext}", ERB.new(
    *[
  <<~'TCODE'
<% if use_typescript %>
import { Head } from '@inertiajs/react'

interface HomeProps {
  rails_version: string
  ruby_version: string
  inertia_rails_version: string
}

export default function Home({ rails_version, ruby_version, inertia_rails_version }: HomeProps) {
<% else %>
import { Head } from '@inertiajs/react'

export default function Home({ rails_version, ruby_version, inertia_rails_version }) {
<% end %>
  return (
    <>
      <Head title="Welcome" />
<% if use_tailwind %>
      <div className="flex min-h-screen items-center justify-center bg-gray-50">
        <div className="mx-auto max-w-md space-y-6 p-8 text-center">
          <h1 className="text-4xl font-bold text-gray-900">Welcome to Inertia Rails</h1>
          <p className="text-lg text-gray-600">
            Your app is ready. Start building something amazing.
          </p>
          <div className="space-y-2 text-sm text-gray-500">
            <p>Rails {rails_version} &middot; Ruby {ruby_version}</p>
            <p>Inertia Rails {inertia_rails_version}</p>
          </div>
          <div className="pt-4">
            <a
              href="https://inertia-rails.dev"
              className="inline-flex items-center rounded-md bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-800"
              target="_blank"
              rel="noopener noreferrer"
            >
              Documentation
            </a>
          </div>
        </div>
      </div>
<% else %>
      <div style={{ display: 'flex', minHeight: '100vh', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ maxWidth: '28rem', margin: '0 auto', padding: '2rem', textAlign: 'center' }}>
          <h1 style={{ fontSize: '2rem', fontWeight: 'bold', marginBottom: '1rem' }}>Welcome to Inertia Rails</h1>
          <p style={{ color: '#666', marginBottom: '1rem' }}>
            Your app is ready. Start building something amazing.
          </p>
          <p style={{ fontSize: '0.875rem', color: '#999' }}>
            Rails {rails_version} &middot; Ruby {ruby_version} &middot; Inertia Rails {inertia_rails_version}
          </p>
          <div style={{ marginTop: '1.5rem' }}>
            <a
              href="https://inertia-rails.dev"
              style={{ padding: '0.5rem 1rem', backgroundColor: '#111', color: '#fff', borderRadius: '0.375rem', textDecoration: 'none' }}
              target="_blank"
              rel="noopener noreferrer"
            >
              Documentation
            </a>
          </div>
        </div>
      </div>
<% end %>
    </>
  )
}
  TCODE
  ], trim_mode: "<>").result(binding)
  when "vue"
    file "#{js_destination_path}/pages/home/index.vue", ERB.new(
    *[
  <<~'TCODE'
<template>
  <Head title="Welcome" />
<% if use_tailwind %>
  <div class="flex min-h-screen items-center justify-center bg-gray-50">
    <div class="mx-auto max-w-md space-y-6 p-8 text-center">
      <h1 class="text-4xl font-bold text-gray-900">Welcome to Inertia Rails</h1>
      <p class="text-lg text-gray-600">
        Your app is ready. Start building something amazing.
      </p>
      <div class="space-y-2 text-sm text-gray-500">
        <p>Rails {{ rails_version }} &middot; Ruby {{ ruby_version }}</p>
        <p>Inertia Rails {{ inertia_rails_version }}</p>
      </div>
      <div class="pt-4">
        <a
          href="https://inertia-rails.dev"
          class="inline-flex items-center rounded-md bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-800"
          target="_blank"
          rel="noopener noreferrer"
        >
          Documentation
        </a>
      </div>
    </div>
  </div>
<% else %>
  <div style="display: flex; min-height: 100vh; align-items: center; justify-content: center">
    <div style="max-width: 28rem; margin: 0 auto; padding: 2rem; text-align: center">
      <h1 style="font-size: 2rem; font-weight: bold; margin-bottom: 1rem">Welcome to Inertia Rails</h1>
      <p style="color: #666; margin-bottom: 1rem">
        Your app is ready. Start building something amazing.
      </p>
      <p style="font-size: 0.875rem; color: #999">
        Rails {{ rails_version }} &middot; Ruby {{ ruby_version }} &middot; Inertia Rails {{ inertia_rails_version }}
      </p>
      <div style="margin-top: 1.5rem">
        <a
          href="https://inertia-rails.dev"
          style="padding: 0.5rem 1rem; background-color: #111; color: #fff; border-radius: 0.375rem; text-decoration: none"
          target="_blank"
          rel="noopener noreferrer"
        >
          Documentation
        </a>
      </div>
    </div>
  </div>
<% end %>
</template>

<% if use_typescript %>
<script setup lang="ts">
import { Head } from '@inertiajs/vue3'

defineProps<{
  rails_version: string
  ruby_version: string
  inertia_rails_version: string
}>()
</script>
<% else %>
<script setup>
import { Head } from '@inertiajs/vue3'

defineProps({
  rails_version: String,
  ruby_version: String,
  inertia_rails_version: String,
})
</script>
<% end %>
  TCODE
  ], trim_mode: "<>").result(binding)
  when "svelte"
    file "#{js_destination_path}/pages/home/index.svelte", ERB.new(
    *[
  <<~'TCODE'
<% if use_typescript %>
<script lang="ts">
  interface Props {
    rails_version: string
    ruby_version: string
    inertia_rails_version: string
  }

  let { rails_version, ruby_version, inertia_rails_version }: Props = $props()
</script>
<% else %>
<script>
  let { rails_version, ruby_version, inertia_rails_version } = $props()
</script>
<% end %>

<svelte:head>
  <title>Welcome</title>
</svelte:head>

<% if use_tailwind %>
<div class="flex min-h-screen items-center justify-center bg-gray-50">
  <div class="mx-auto max-w-md space-y-6 p-8 text-center">
    <h1 class="text-4xl font-bold text-gray-900">Welcome to Inertia Rails</h1>
    <p class="text-lg text-gray-600">
      Your app is ready. Start building something amazing.
    </p>
    <div class="space-y-2 text-sm text-gray-500">
      <p>Rails {rails_version} &middot; Ruby {ruby_version}</p>
      <p>Inertia Rails {inertia_rails_version}</p>
    </div>
    <div class="pt-4">
      <a
        href="https://inertia-rails.dev"
        class="inline-flex items-center rounded-md bg-gray-900 px-4 py-2 text-sm font-medium text-white hover:bg-gray-800"
        target="_blank"
        rel="noopener noreferrer"
      >
        Documentation
      </a>
    </div>
  </div>
</div>
<% else %>
<div style="display: flex; min-height: 100vh; align-items: center; justify-content: center">
  <div style="max-width: 28rem; margin: 0 auto; padding: 2rem; text-align: center">
    <h1 style="font-size: 2rem; font-weight: bold; margin-bottom: 1rem">Welcome to Inertia Rails</h1>
    <p style="color: #666; margin-bottom: 1rem">
      Your app is ready. Start building something amazing.
    </p>
    <p style="font-size: 0.875rem; color: #999">
      Rails {rails_version} &middot; Ruby {ruby_version} &middot; Inertia Rails {inertia_rails_version}
    </p>
    <div style="margin-top: 1.5rem">
      <a
        href="https://inertia-rails.dev"
        style="padding: 0.5rem 1rem; background-color: #111; color: #fff; border-radius: 0.375rem; text-decoration: none"
        target="_blank"
        rel="noopener noreferrer"
      >
        Documentation
      </a>
    </div>
  </div>
</div>
<% end %>
  TCODE
  ], trim_mode: "<>").result(binding)
  end

  say "  Welcome page created ✓", :green
end
# ─── Deployment Infrastructure ────────────────────────────────────────
# Dockerfile, CI workflow, Dependabot

js_ci_install_cmd = case package_manager
  when "yarn" then "yarn install --immutable"
  when "pnpm" then "pnpm install --frozen-lockfile"
  when "bun"  then "bun install --frozen-lockfile"
  else "npm ci"
end

# ─── Generate Dockerfile ─────────────────────────────────────────────

if File.exist?("Dockerfile")
  ruby_version = File.exist?(".ruby-version") ? File.read(".ruby-version").strip.delete_prefix("ruby-") : Gem.ruby_version.to_s
  node_version = ENV.fetch("NODE_VERSION") { `node --version`[/\d+\.\d+\.\d+/] || "22.21.1" }

  db_base_pkg = case db_adapter
    when "postgresql" then "postgresql-client"
    when "mysql2", "trilogy" then "default-mysql-client"
    else "sqlite3"
  end

  db_build_pkg = case db_adapter
    when "postgresql" then "libpq-dev"
    when "mysql2" then "default-libmysqlclient-dev"
    else nil
  end

  use_thruster = gem_in_gemfile.("thruster")

  file "Dockerfile", ERB.new(
    *[
  <<~'TCODE'
# syntax=docker/dockerfile:1
# check=error=true

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=<%= ruby_version %>
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Set to "true" to enable server-side rendering
ARG SSR_ENABLED=<%= use_ssr ? "true" : "false" %>

WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips <%= db_base_pkg %> && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

<% if package_manager == "bun" %>
# Install Bun (needed for builds; kept in runtime for SSR)
ENV BUN_INSTALL=/usr/local/bun
ENV PATH=/usr/local/bun/bin:$PATH
ARG BUN_VERSION=1.2
RUN curl -fsSL https://bun.sh/install | bash -s -- "bun-v${BUN_VERSION}"
<% else %>
# Install Node.js (needed for builds; kept in runtime for SSR)
ARG NODE_VERSION=<%= node_version %>
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    rm -rf /tmp/node-build-master
<% end %>

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

FROM base AS build

# Install packages needed to build gems and node modules
<% if package_manager == "bun" %>
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git unzip<%= " #{db_build_pkg}" if db_build_pkg %> libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
<% else %>
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git node-gyp python-is-python3<%= " #{db_build_pkg}" if db_build_pkg %> libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
<% end %>

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

<% if package_manager == "bun" %>
# Install node modules
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile
<% else %>
# Install node modules
<%   lockfile = case package_manager
       when "yarn" then "yarn.lock"
       when "pnpm" then "pnpm-lock.yaml"
       else "package-lock.json"
     end
     pm_ci_cmd = case package_manager
       when "yarn" then "yarn install --immutable"
       when "pnpm" then "pnpm install --frozen-lockfile"
       else "npm ci"
     end
%>
COPY package.json <%= lockfile %> ./
RUN <%= pm_ci_cmd %>
<% end %>

# Copy application code
COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
<% vite_build_cmd = case package_manager
     when "yarn" then "yarn vite build"
     when "pnpm" then "pnpm vite build"
     when "bun" then "bun run vite build"
     else "npx vite build"
   end
%>
ARG SSR_ENABLED
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    if [ "$SSR_ENABLED" = "true" ]; then <%= vite_build_cmd %> --ssr; fi

RUN rm -rf node_modules

FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE <%= use_thruster ? 80 : 3000 %>
CMD <%= use_thruster ? '["./bin/thrust", "./bin/rails", "server"]' : '["./bin/rails", "server"]' %>
  TCODE
  ], trim_mode: "<>").result(binding), force: fresh_app
  say "  Dockerfile: generated with Node.js support ✓", :green
end

# ─── Generate CI workflow ────────────────────────────────────────────

ci_workflow = ".github/workflows/ci.yml"
if File.exist?(ci_workflow)
  if fresh_app
    file ci_workflow, ERB.new(
    *[
  <<~'TCODE'
name: CI

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
<% if File.exist?("bin/brakeman") || File.exist?("bin/bundler-audit") %>
  scan_ruby:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
<% if File.exist?("bin/brakeman") %>

      - name: Scan for common Rails security vulnerabilities using static analysis
        run: bin/brakeman --no-pager
<% end %>
<% if File.exist?("bin/bundler-audit") %>

      - name: Scan for known security vulnerabilities in gems used
        run: bin/bundler-audit
<% end %>

<% end %>
  lint_js:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v6
<% if package_manager == "bun" %>

      - name: Set up Bun
        uses: oven-sh/setup-bun@v2
<% else %>

      - name: Set up Node.js
        uses: actions/setup-node@v6
        with:
          node-version: 22
<% unless package_manager == "npm" %>
          cache: <%= package_manager %>
<% end %>
<% if package_manager == "pnpm" %>

      - name: Set up pnpm
        uses: pnpm/action-setup@v4
<% end %>
<% end %>

      - name: Install JS dependencies
        run: <%= js_ci_install_cmd %>
<% if use_eslint %>

      - name: Lint JavaScript
        run: <%= package_manager %> run lint

      - name: Check formatting
        run: <%= package_manager %> run format
<% end %>
<% if use_typescript %>

      - name: Type check
        run: <%= package_manager %> run check
<% end %>

<% if File.exist?("bin/rubocop") %>
  lint:
    runs-on: ubuntu-latest
    env:
      RUBOCOP_CACHE_ROOT: tmp/rubocop
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Prepare RuboCop cache
        uses: actions/cache@v4
        env:
          DEPENDENCIES_HASH: ${{ hashFiles('.ruby-version', '**/.rubocop.yml', '**/.rubocop_todo.yml', 'Gemfile.lock') }}
        with:
          path: ${{ env.RUBOCOP_CACHE_ROOT }}
          key: rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-${{ github.ref_name == github.event.repository.default_branch && github.run_id || 'default' }}
          restore-keys: |
            rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-

      - name: Lint code for consistent style
        run: bin/rubocop -f github

<% end %>
  test:
    runs-on: ubuntu-latest
<% case db_adapter
   when "postgresql" %>

    services:
      postgres:
        image: postgres
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: --health-cmd="pg_isready" --health-interval=10s --health-timeout=5s --health-retries=3
<% when "mysql2", "trilogy" %>

    services:
      mysql:
        image: mysql
        env:
          MYSQL_ALLOW_EMPTY_PASSWORD: true
        ports:
          - 3306:3306
        options: --health-cmd="mysqladmin ping" --health-interval=10s --health-timeout=5s --health-retries=3
<% end %>

    steps:
<% if db_adapter == "postgresql" %>
      - name: Install packages
        run: sudo apt-get update && sudo apt-get install --no-install-recommends -y libpq-dev

<% elsif db_adapter == "mysql2" %>
      - name: Install packages
        run: sudo apt-get update && sudo apt-get install --no-install-recommends -y default-libmysqlclient-dev

<% end %>
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
<% if package_manager == "bun" %>

      - name: Set up Bun
        uses: oven-sh/setup-bun@v2
<% else %>

      - name: Set up Node.js
        uses: actions/setup-node@v6
        with:
          node-version: 22
<% unless package_manager == "npm" %>
          cache: <%= package_manager %>
<% end %>
<% if package_manager == "pnpm" %>

      - name: Set up pnpm
        uses: pnpm/action-setup@v4
<% end %>
<% end %>

      - name: Install JS dependencies
        run: <%= js_ci_install_cmd %>

      - name: Run tests
        env:
          RAILS_ENV: test
<% case db_adapter
   when "postgresql" %>
          DATABASE_URL: postgres://postgres:postgres@localhost:5432
<% when "mysql2" %>
          DATABASE_URL: mysql2://127.0.0.1:3306
<% when "trilogy" %>
          DATABASE_URL: trilogy://127.0.0.1:3306
<% end %>
        run: bin/rails db:test:prepare test
  TCODE
  ], trim_mode: "<>").result(binding), force: true
    say "  CI: generated workflow with lint_js + Node.js ✓", :green
  else
    # ── Existing app: minimal fixes ────────────────────────────────────

    ci_content = File.read(ci_workflow)

    # Remove broken scan_js job (importmap no longer exists)
    if ci_content.include?("bin/importmap audit")
      lines = ci_content.lines
      result = []
      skip = false
      lines.each do |line|
        if line.match?(/^  scan_js:/)
          skip = true
          next
        end
        if skip && line.match?(/^  \w/)
          skip = false
        end
        result << line unless skip
      end
      File.write(File.join(destination_root, ci_workflow), result.join)
      say "  CI: removed broken scan_js job ✓", :green
    end

    # Create separate lint_js workflow
    file ".github/workflows/lint_js.yml", ERB.new(
    *[
  <<~'TCODE'
name: Lint JS

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  lint_js:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v6
<% if package_manager == "bun" %>

      - name: Set up Bun
        uses: oven-sh/setup-bun@v2
<% else %>

      - name: Set up Node.js
        uses: actions/setup-node@v6
        with:
          node-version: 22
<% unless package_manager == "npm" %>
          cache: <%= package_manager %>
<% end %>
<% if package_manager == "pnpm" %>

      - name: Set up pnpm
        uses: pnpm/action-setup@v4
<% end %>
<% end %>

      - name: Install JS dependencies
        run: <%= js_ci_install_cmd %>
<% if use_eslint %>

      - name: Lint JavaScript
        run: <%= package_manager %> run lint

      - name: Check formatting
        run: <%= package_manager %> run format
<% end %>
<% if use_typescript %>

      - name: Type check
        run: <%= package_manager %> run check
<% end %>
  TCODE
  ], trim_mode: "<>").result(binding)
    say "  CI: created lint_js workflow ✓", :green
    say "  ⚠ You may want to add Node.js setup to the test job in #{ci_workflow}", :yellow
  end
end

# ─── Add npm to Dependabot ────────────────────────────────────────────

dependabot_file = ".github/dependabot.yml"
if File.exist?(dependabot_file)
  dependabot_config = File.read(dependabot_file)
  unless dependabot_config.include?("package-ecosystem: npm")
    append_with_blank_line.(dependabot_file, <<~YAML)
      - package-ecosystem: npm
        directory: "/"
        schedule:
          interval: weekly
    YAML
    say "  Dependabot: added npm ecosystem ✓", :green
  end
end
# ─── Finalize ────────────────────────────────────────────────────────

say "📦 Finalizing installation...", :cyan

# ─── Install gems ───────────────────────────────────────────────────

# Add remaining gems to Gemfile (rails_vite & inertia_rails already added via add_gem)
gems_to_add.uniq! { |e| e.is_a?(Hash) ? e[:name] : e }
gems_to_add.each do |entry|
  if entry.is_a?(Hash)
    add_gem.(entry[:name], group: entry[:group])
  else
    add_gem.(entry)
  end
end

# Single bundle install for all gems
bundle_run.("bundle install")

if test_framework == "rspec"
  bundle_run.("bundle binstubs rspec-core")
end

# ─── Run migrations (starter kit) ────────────────────────────────────

if use_starter_kit
  bundle_run.("bundle exec rails db:migrate")
end

# ─── Generate Typelizer files ──────────────────────────────────────

if use_typelizer || (use_alba && use_typescript)
  file "config/initializers/typelizer.rb", ERB.new(
    *[
  <<~'TCODE'
# frozen_string_literal: true

Typelizer.configure do |config|
  config.verbatim_module_syntax = true
<% if use_typelizer %>
  config.routes.enabled = true
  config.routes.output_dir = Rails.root.join("<%= js_destination_path %>/routes")
  config.routes.exclude = [ /^\/(up|rails)/ ]
<% unless use_typescript %>
  config.routes.format = :js
<% end %>
<% end %>
<% if use_alba && use_typescript %>
  config.output_dir = Rails.root.join("<%= js_destination_path %>/types/serializers")
<% end %>
end
  TCODE
  ], trim_mode: "<>").result(binding)
  bundle_run.("bundle exec rails typelizer:generate")
end

# ─── Batch npm install ──────────────────────────────────────────────

npm_packages.uniq!
npm_dev_packages.uniq!

install_cmd  = pm_install[package_manager][:install]
dev_flag     = pm_install[package_manager][:dev_flag]

if npm_packages.any?
  run "#{install_cmd} #{npm_packages.join(' ')}"
end

if npm_dev_packages.any?
  run "#{install_cmd} #{dev_flag} #{npm_dev_packages.join(' ')}"
end

# ─── Run post-install commands (e.g. shadcn CLI) ──────────────────

post_install_commands.each { |cmd| run cmd }

# ─── Re-apply files the shadcn CLI overwrites ────────────────────
# `shadcn add sidebar` pulls its own use-mobile hook as a dependency and
# clobbers ours. The upstream version triggers react-hooks/set-state-in-effect
# (added in eslint-plugin-react-hooks 7.1); ours uses useSyncExternalStore.
if use_starter_kit && framework == "react"
  file "#{js_destination_path}/hooks/use-mobile.ts", ERB.new(
    *[
  <<~'TCODE'
import { useSyncExternalStore } from "react"

import { isBrowser } from "@/lib/browser"

const MOBILE_BREAKPOINT = 768

const mql = isBrowser
  ? window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`)
  : null

function mediaQueryListener(callback: (event: MediaQueryListEvent) => void) {
  mql?.addEventListener("change", callback)

  return () => {
    mql?.removeEventListener("change", callback)
  }
}

function isSmallerThanBreakpoint() {
  return mql?.matches ?? false
}

export function useIsMobile() {
  return useSyncExternalStore(
    mediaQueryListener,
    isSmallerThanBreakpoint,
    () => false,
  )
}
  TCODE
  ], trim_mode: "<>").result(binding), force: true
end

# ─── Write vite.config ──────────────────────────────────────────────

vite_plugins.uniq! { |p| [p[:import], p[:call]] }

existing_vite_config = Dir.glob(vite_config_glob).first

if existing_vite_config && vite_plugins.any?
  # Existing app: inject plugins into existing config
  vite_config = File.read(existing_vite_config)

  vite_plugins.each do |plugin|
    unless vite_config.include?(plugin[:import])
      prepend_file existing_vite_config, "#{plugin[:import]}\n"
    end
  end

  # Re-read after prepends so call-detection sees current file
  vite_config = File.read(existing_vite_config)

  vite_plugins.each do |plugin|
    unless vite_config.include?(plugin[:call])
      insert_into_file existing_vite_config, "\n    #{plugin[:call]},", after: "plugins: ["
    end
  end

  if !vite_config.include?("noExternal")
    say "  ⚠ For SSR production builds, add this to your vite.config:", :yellow
    say "    ssr: command === 'build' ? { noExternal: true } : {}", :yellow
    say "    (use defineConfig(({ command }) => ({ ... })) form)", :yellow
  end
else
  # Fresh app: write complete vite.config from scratch
  vite_imports = ["import { defineConfig } from 'vite'", "import rails from 'rails-vite-plugin'", "import inertia from '@inertiajs/vite'"]

  # Always configure SSR entrypoint so apps are SSR-ready
  ssr_entrypoint = case framework
    when "react" then "entrypoints/inertia.#{component_ext}"
    else "entrypoints/inertia.#{js_ext}"
  end
  ssr_entry_full = "#{js_destination_path}/#{ssr_entrypoint}"

  vite_calls = ["rails()", "inertia({ ssr: '#{ssr_entry_full}' })"]

  vite_plugins.each do |plugin|
    vite_imports << plugin[:import]
    vite_calls << plugin[:call]
  end

  # SSR config: noExternal for production builds (containerization without node_modules)
  ssr_config = "noExternal: command === 'build' ? true : undefined,"
  if framework == "react"
    # React 19 ships CJS-only — externalize in dev so Node handles require natively
    ssr_config += "\n      external: command === 'serve' ? ['react', 'react-dom', 'react/jsx-runtime', 'react/jsx-dev-runtime'] : undefined,"
  end

  file "vite.config.#{js_ext}", <<~JS
    #{vite_imports.join("\n")}

    export default defineConfig(({ command }) => ({
      ssr: {
        #{ssr_config}
      },
      plugins: [
        #{vite_calls.join(",\n    ")},
      ],
    }))
  JS
end

# ─── Auto-fix lint issues ────────────────────────────────────────────

if use_eslint
  unless run("#{package_manager} run lint:fix", abort_on_failure: false)
    say "  ⚠ lint:fix exited with errors (non-critical, continuing)", :yellow
  end
  run("#{package_manager} run format:fix", abort_on_failure: false)
end

# ─── Create/update Procfile.dev ──────────────────────────────────────

vite_dev_cmd = case package_manager
  when "yarn" then "yarn vite"
  when "pnpm" then "pnpm vite"
  when "bun" then "bun run vite"
  else "npx vite"
end

file "Procfile.dev", "web: bin/rails s -p ${PORT:-3000}\njs: #{vite_dev_cmd}\n", force: fresh_app

# ─── Create bin/dev ──────────────────────────────────────────────────

file "bin/dev", ERB.new(
    *[
  <<~'TCODE'
#!/usr/bin/env sh

export PORT="${PORT:-3000}"

if command -v overmind 1> /dev/null 2>&1
then
  overmind start -f Procfile.dev "$@"
  exit $?
fi

if command -v hivemind 1> /dev/null 2>&1
then
  echo "Hivemind is installed. Running the application with Hivemind..."
  exec hivemind Procfile.dev "$@"
  exit $?
fi

if gem list --no-installed --exact --silent foreman; then
  echo "Installing foreman..."
  gem install foreman
fi

foreman start -f Procfile.dev "$@"
  TCODE
  ], trim_mode: "<>").result(binding), force: fresh_app
chmod "bin/dev", 0o755

# ─── Post-install verification ─────────────────────────────────────

say "🔍 Verifying installation...", :cyan

if in_root { run("bundle exec rails runner 'puts :ok'") }
  say "  Rails boot check passed ✓", :green
else
  say "  ⚠ Rails boot check failed (the app may still work — check the error above)", :yellow
end

# ─── Summary (after all post-template steps) ─────────────────────────

after_bundle do
  say ""
  say "━━━ Inertia Rails installed successfully! ━━━━━━━━━━━━━━━━━━━━━", :green
  say ""
  say "  Start the development server:", :cyan
  say "    bin/dev"
  say ""

  if use_starter_kit
    say "  Starter Kit with authentication is ready.", :cyan
    say ""
  end

  if use_ssr
    say "  SSR is enabled. Production build:", :cyan
    say "    #{vite_dev_cmd.split.first} vite build --ssr"
    say ""
  else
    say "  SSR-ready. To enable, add to config/initializers/inertia_rails.rb:", :cyan
    say "    config.ssr_enabled = true"
    say ""
  end

  if importmap_detected
    say "  ⚠ importmap-rails is still installed.", :yellow
    say "    It works alongside Vite but you may want to remove it.", :yellow
    say ""
  end

  say "  Learn more: https://inertia-rails.dev", :cyan
  say ""
end
