# frozen_string_literal: true

require "test_helper"

class TemplateTest < Minitest::Test
  def test_template_compiles
    assert compile
  end

  def test_stamps_short_commit_sha_from_ci
    with_env("GITHUB_SHA" => "0123456789abcdef0123456789abcdef01234567") do
      assert_includes compile, 'generator_version = "01234567"'
    end
  end

  def test_stamps_dev_for_local_builds
    with_env("GITHUB_SHA" => nil) do
      assert_includes compile, 'generator_version = "dev"'
    end
  end

  private

  def compile
    RubyBytes::Compiler.new(File.join(__dir__, "../template/generator.rb")).render
  end

  def with_env(vars)
    original = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end
