# frozen_string_literal: true

require "tmpdir"

module E2eHelpers
  COMMON_ENV = {
    "INERTIA_TEST_FRAMEWORK" => "minitest",
    "INERTIA_ALBA" => "0",
    "INERTIA_TYPELIZER" => "0"
  }.freeze

  # Shared flags for all configs (none currently)
  RAILS_FLAGS = [].freeze

  # Starter kit: NO flags — test the real `rails new` experience
  STARTER_KIT_FLAGS = [].freeze

  # Foundation: skip features the generator doesn't touch (for speed)
  FOUNDATION_FLAGS = %w[
    --skip-test --skip-action-mailer --skip-active-job
    --skip-action-mailbox --skip-action-text --skip-active-storage
    --skip-action-cable --skip-jbuilder
  ].freeze

  TEMPLATE_ROOT = File.expand_path("../../template/generator.rb", __dir__)

  def self.compile_template(path = compiled_template_path)
    require "ruby_bytes/cli"
    $LOAD_PATH.unshift File.expand_path("../../lib", __dir__) unless $LOAD_PATH.include?(File.expand_path("../../lib", __dir__))
    require "ruby_bytes_ext"
    compiled = RubyBytes::Compiler.new(TEMPLATE_ROOT).render
    File.write(path, compiled)
    path
  end

  def self.compiled_template_path
    File.join(Dir.tmpdir, "inertia_e2e_template.rb")
  end
end
