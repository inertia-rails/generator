# frozen_string_literal: true

begin
  require "debug" unless ENV["CI"]
rescue LoadError
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rbytes"
require "ruby_bytes/test_case"
require "ruby_bytes_ext"

# rbytes' route helper calls String#strip_heredoc and String#indent
# (ActiveSupport), which aren't available in our minimal test environment.
# Polyfill them so templates using `route` can be exercised via run_generator.
unless String.method_defined?(:strip_heredoc)
  class String
    def strip_heredoc
      indent = scan(/^[ \t]*(?=\S)/).min
      indent ? gsub(/^[ \t]{#{indent.size}}/, "") : dup
    end
  end
end

unless String.method_defined?(:indent)
  class String
    def indent(amount, indent_string = nil, indent_empty_lines = false)
      indent_string = indent_string || self[/^[ \t]/] || " "
      re = indent_empty_lines ? /^/ : /^(?!$)/
      gsub(re) { indent_string * amount }
    end
  end
end
# rbytes 0.3+ prepends Charmed into Thor::Shell::Color, which uses gum for
# interactive prompts (ask, yes?, no?). gum requires a TTY, so we bypass it
# in tests by falling back to Thor::Shell::Basic's implementation.
# rubocop:disable Style/GlobalVars
if defined?(Rbytes::Charmed)
  Rbytes::Charmed.prepend(Module.new do
    def ask(statement, *args)
      return super unless $rbytes_testing
      Thor::Shell::Basic.instance_method(:ask).bind_call(self, statement, *args)
    end

    def yes?(statement, color = nil)
      return super unless $rbytes_testing
      Thor::Shell::Basic.instance_method(:yes?).bind_call(self, statement, color)
    end

    def no?(statement, color = nil)
      return super unless $rbytes_testing
      Thor::Shell::Basic.instance_method(:no?).bind_call(self, statement, color)
    end
  end)
end
# rubocop:enable Style/GlobalVars

require "minitest/autorun"
require "minitest/focus"
require "minitest/reporters"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class GeneratorTestCase < RubyBytes::TestCase
  root File.join(__dir__, "../template")
  dummy_app File.join(__dir__, "fixtures", "basic_rails_app")

  # rbytes 0.3+ uses Charmed shell which accumulates say() output in a box buffer.
  # Append say("") to flush the buffer so assert_line_printed can see all output.
  def self.template(contents)
    super(contents.rstrip + "\nsay \"\"\n")
  end

  # rbytes 0.3+ uses gum/Charmed for interactive prompts which requires a TTY.
  # Bypass Charmed's ask/yes?/no? in tests to avoid gum TTY requirement.
  def run_generator(...)
    $rbytes_testing = true # rubocop:disable Style/GlobalVars
    super
  ensure
    $rbytes_testing = false # rubocop:disable Style/GlobalVars
  end

  # ─── Common lambda snippets for template composition ──────────────
  # Tests compose templates by string interpolation: #{UPDATE_PACKAGE_JSON}

  UPDATE_PACKAGE_JSON = <<~'RUBY'
    update_package_json = ->(&block) {
      return unless File.exist?("package.json")
      pkg = JSON.parse(File.read("package.json"))
      block.call(pkg)
      File.write("package.json", JSON.pretty_generate(pkg) + "\n")
    }
  RUBY

  GEM_IN_GEMFILE = <<~'RUBY'
    gem_in_gemfile = ->(name) {
      return false unless File.exist?("Gemfile")
      File.read("Gemfile").match?(/^\s*gem\s+['"]#{name}['"]/)
    }
  RUBY

  ADD_GEM = <<~'RUBY'
    add_gem = ->(name, comment: nil, group: nil, github: nil, branch: nil) {
      entry = "gem \"#{name}\""
      entry += ", github: \"#{github}\"" if github
      entry += ", branch: \"#{branch}\"" if branch
      if group
        groups = Array(group).map(&:inspect).join(", ")
        entry += ", group: [#{groups}]"
      end
      entry += " # #{comment}" if comment
      append_to_file "Gemfile", "#{entry}\n"
    }
  RUBY

  NOOP_ADD_GEM = "add_gem = ->(name, comment: nil, group: nil, github: nil, branch: nil) {}"

  REMOVE_GEM = <<~'RUBY'
    remove_gem = ->(name) {
      gsub_file "Gemfile", /^\s*gem\s+['"]#{Regexp.escape(name)}['"].*\n/, ""
    }
  RUBY

  UPDATE_JSON_FILE = <<~'RUBY'
    update_json_file = ->(path, &block) {
      return unless File.exist?(path)
      json = JSON.parse(File.read(path))
      block.call(json)
      File.write(path, JSON.pretty_generate(json) + "\n")
    }
  RUBY

  STUB_PACKAGE_JSON = 'file "package.json", \'{"name":"test","private":true,"scripts":{}}\''

  PM_INSTALL = <<~RUBY
    pm_install = {
      "npm"  => { install: "npm install",  dev_flag: "--save-dev" },
      "yarn" => { install: "yarn add",     dev_flag: "--dev" },
      "pnpm" => { install: "pnpm add",     dev_flag: "--save-dev" },
      "bun"  => { install: "bun add",      dev_flag: "--dev" }
    }
  RUBY

  # Shared preamble for deploy/finalize tests (state variables matching generator.rb)
  DEPLOY_PREAMBLE = <<~CODE
    framework = "react"
    use_typescript = false
    use_tailwind = false
    use_shadcn = false
    use_eslint = false
    use_ssr = false
    use_starter_kit = false
    use_typelizer = false
    use_alba = false
    package_manager = "npm"
    js_destination_path = "app/javascript"
    js_ext = "js"
    component_ext = "jsx"
    fresh_app = true
    #{PM_INSTALL}
    #{GEM_IN_GEMFILE}
    db_adapter = "sqlite3"
  CODE
end
