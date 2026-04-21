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
fresh_app           = nil
vite_installed      = false
framework_detected  = nil
typescript_detected = false
tailwind_detected   = false
importmap_detected  = false
package_manager     = "npm"
db_adapter          = "sqlite3"

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

# ─── Phase 1: Detect + Prompt ──────────────────────────────────────

<%= include "detect" %>
<%= include "prompts" %>

# Compute derived state
js_ext = use_typescript ? "ts" : "js"
component_ext = case framework
  when "react" then use_typescript ? "tsx" : "jsx"
  when "vue" then "vue"
  when "svelte" then "svelte"
end

# Source directory for frontend code
js_destination_path = "app/javascript"

# ─── Phase 2: Core Infrastructure ──────────────────────────────────

<%= include "cleanup" %>
<%= include "vite" %>
<%= include "typescript" %>
<%= include "tailwind" %>

# ─── Phase 3: Inertia ──────────────────────────────────────────────

<%= include "inertia" %>
<%= include "inertia_entrypoint" %>

# ─── Phase 4: Tooling + UI ─────────────────────────────────────────

<%= include "shadcn" %>
<%= include "typelizer" %>

# ─── Phase 5: Starter Kit ─────────────────────────────────────────

<%= include "starter_backend" %>
<%= include "starter_frontend" %>

# ─── Phase 6: Optional Tools ──────────────────────────────────────

<%= include "alba" %>
<%= include "test_framework" %>
<%= include "eslint" %>

# ─── Phase 7: Deploy + Finalize ───────────────────────────────────────

<%= include "example_page" %>
<%= include "deploy" %>
<%= include "finalize" %>
