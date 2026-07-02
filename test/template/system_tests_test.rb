# frozen_string_literal: true

require_relative "../test_helper"

class SystemTestsRspecStarterTest < GeneratorTestCase
  template <<~CODE
    use_system_tests = true
    use_starter_kit = true
    test_framework = "rspec"
    gems_to_add = []

    append_to_file "Gemfile", <<~GEMFILE

      group :test do
        # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
        gem "capybara"
        gem "selenium-webdriver"
      end
    GEMFILE

    file "app/views/layouts/application.html.erb", <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <%%= csrf_meta_tags %>
        </head>
      </html>
    HTML

    file "spec/rails_helper.rb", <<~RUBY
      require "rspec/rails"

      RSpec.configure do |config|
        config.filter_rails_from_backtrace!

        config.include ActiveSupport::Testing::TimeHelpers
      end
    RUBY

    <%= include "system_tests" %>
  CODE

  def test_inserts_lockstep_gem_into_test_group
    run_generator do
      gemfile = File.read(File.join(destination, "Gemfile"))
      assert gemfile.include?('gem "capybara-lockstep"'), "Gemfile missing capybara-lockstep"
      assert gemfile.include?("Synchronize Capybara commands"), "Missing lockstep comment"
      assert gemfile.index("capybara-lockstep") > gemfile.index('gem "capybara"'), "lockstep should follow capybara"
      assert gemfile.index("capybara-lockstep") < gemfile.index("selenium-webdriver"), "lockstep should precede selenium-webdriver"
    end
  end

  def test_adds_lockstep_layout_tag
    run_generator do
      layout = File.read(File.join(destination, "app/views/layouts/application.html.erb"))
      assert layout.include?("<%= capybara_lockstep if defined?(Capybara::Lockstep) %>"), "Layout missing lockstep tag"
      assert layout.index("capybara_lockstep") < layout.index("csrf_meta_tags"), "lockstep tag should precede csrf_meta_tags"
    end
  end

  def test_wires_rspec_driver
    run_generator do
      rails_helper = File.read(File.join(destination, "spec/rails_helper.rb"))
      assert rails_helper.include?('require "capybara/rspec"'), "Missing capybara/rspec require"
      assert rails_helper.include?('require "selenium-webdriver"'), "Missing selenium-webdriver require"
      assert rails_helper.include?("driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]"), "Missing driven_by"
      assert rails_helper.index("driven_by") < rails_helper.index("TimeHelpers"), "driven_by block should precede TimeHelpers include"
    end
  end

  def test_creates_example_system_spec
    run_generator do
      assert_file "spec/system/sessions_spec.rb"
      assert_file_contains "spec/system/sessions_spec.rb", 'fill_in "Email address"'
      assert_file_contains "spec/system/sessions_spec.rb", "dashboard_path"
    end
  end
end

class SystemTestsMinitestStarterTest < GeneratorTestCase
  template <<~CODE
    use_system_tests = true
    use_starter_kit = true
    test_framework = "minitest"
    gems_to_add = []

    append_to_file "Gemfile", <<~GEMFILE

      group :test do
        gem "capybara"
        gem "selenium-webdriver"
      end
    GEMFILE

    file "test/test_helper.rb", <<~RUBY
      require "rails/test_help"
    RUBY

    file "test/application_system_test_case.rb", <<~RUBY
      require "test_helper"

      class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
        driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
      end
    RUBY

    <%= include "system_tests" %>
  CODE

  def test_creates_example_system_test
    run_generator do
      assert_file "test/system/sessions_test.rb"
      assert_file_contains "test/system/sessions_test.rb", 'fill_in "Email address"'
      assert_file_contains "test/system/sessions_test.rb", "ApplicationSystemTestCase"
    end
  end

  def test_keeps_rails_generated_system_test_case
    run_generator do
      assert_file_contains "test/application_system_test_case.rb", "driven_by :selenium, using: :headless_chrome"
    end
  end
end

class SystemTestsSkipSystemTestFallbackTest < GeneratorTestCase
  template <<~'CODE'
    use_system_tests = true
    use_starter_kit = false
    test_framework = "minitest"
    gems_to_add = []

    file "test/test_helper.rb", <<~RUBY
      require "rails/test_help"
    RUBY

    <%= include "system_tests" %>

    say "GEMS=#{gems_to_add.map { |g| g.is_a?(Hash) ? g[:name] : g }.join(",")}"
  CODE

  def test_adds_gems_when_test_group_missing
    run_generator do |output|
      assert_line_printed output, "GEMS=capybara,selenium-webdriver,capybara-lockstep"
    end
  end

  def test_recreates_system_test_case
    run_generator do
      assert_file "test/application_system_test_case.rb"
      assert_file_contains "test/application_system_test_case.rb", "driven_by :selenium, using: :headless_chrome"
    end
  end
end

class SystemTestsDisabledTest < GeneratorTestCase
  template <<~'CODE'
    use_system_tests = false
    use_starter_kit = true
    test_framework = "rspec"
    gems_to_add = []

    file "spec/rails_helper.rb", <<~RUBY
      require "rspec/rails"
    RUBY

    <%= include "system_tests" %>

    say "GEMS=#{gems_to_add.size}"
  CODE

  def test_does_nothing_when_disabled
    run_generator do |output|
      assert_line_printed output, "GEMS=0"
      gemfile = File.read(File.join(destination, "Gemfile"))
      refute gemfile.include?("capybara-lockstep"), "Should not add lockstep when disabled"
      refute File.exist?(File.join(destination, "spec/system/sessions_spec.rb")), "Should not create example spec when disabled"
      rails_helper = File.read(File.join(destination, "spec/rails_helper.rb"))
      refute rails_helper.include?("driven_by"), "Should not wire driver when disabled"
    end
  end
end
