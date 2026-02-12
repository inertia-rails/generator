# frozen_string_literal: true

require_relative "../test_helper"

class TestFrameworkRspecTest < GeneratorTestCase
  template <<~CODE
    test_framework = "rspec"
    use_starter_kit = false
    gems_to_add = []
    <%= include "test_framework" %>
  CODE

  def test_adds_rspec
    run_generator do |output|
      assert_line_printed output, "Setting up RSpec"
    end
  end
end

class TestFrameworkMinitestTest < GeneratorTestCase
  template <<~CODE
    test_framework = "minitest"
    use_starter_kit = false
    gems_to_add = []
    <%= include "test_framework" %>
  CODE

  def test_skips_for_minitest
    run_generator do |output|
      refute output.include?("Setting up RSpec"), "Should not set up RSpec for minitest"
    end
  end
end

class TestFrameworkStarterMinitestTest < GeneratorTestCase
  template <<~CODE
    test_framework = "minitest"
    use_starter_kit = true
    gems_to_add = []
    file "test/test_helper.rb", <<~RUBY
      require "rails/test_help"
    RUBY
    <%= include "test_framework" %>
  CODE

  def test_creates_fixtures
    run_generator do
      assert_file "test/fixtures/users.yml"
      assert_file_contains "test/fixtures/users.yml", "one@example.com"
    end
  end

  def test_creates_session_test_helper
    run_generator do
      assert_file "test/test_helpers/session_test_helper.rb"
      assert_file_contains "test/test_helpers/session_test_helper.rb", "session_token"
    end
  end

  def test_creates_controller_tests
    run_generator do
      assert_file "test/controllers/sessions_controller_test.rb"
      assert_file "test/controllers/users_controller_test.rb"
      assert_file "test/controllers/identity/email_verifications_controller_test.rb"
      assert_file "test/controllers/identity/password_resets_controller_test.rb"
      assert_file "test/controllers/settings/emails_controller_test.rb"
      assert_file "test/controllers/settings/passwords_controller_test.rb"
      assert_file "test/controllers/settings/sessions_controller_test.rb"
    end
  end

  def test_creates_mailer_test
    run_generator do
      assert_file "test/mailers/user_mailer_test.rb"
    end
  end

  def test_injects_helper_into_test_helper
    run_generator do
      assert_file_contains "test/test_helper.rb", "session_test_helper"
      assert_file_contains "test/test_helper.rb", "SessionTestHelper"
    end
  end

  def test_does_not_create_rspec_files
    run_generator do
      refute_file ".rspec"
      refute_file "spec/rails_helper.rb"
    end
  end
end

class TestFrameworkStarterRspecTest < GeneratorTestCase
  template <<~CODE
    test_framework = "rspec"
    use_starter_kit = true
    gems_to_add = []
    <%= include "test_framework" %>
  CODE

  def test_adds_rspec_gem
    run_generator do |output|
      assert_line_printed output, "Setting up RSpec"
    end
  end

  def test_creates_fixtures
    run_generator do
      assert_file "test/fixtures/users.yml"
    end
  end

  def test_creates_rspec_config_files
    run_generator do
      assert_file ".rspec"
      assert_file "spec/spec_helper.rb"
      assert_file "spec/rails_helper.rb"
      assert_file_contains "spec/rails_helper.rb", "test/fixtures"
    end
  end

  def test_creates_auth_helpers
    run_generator do
      assert_file "spec/support/authentication_helpers.rb"
      assert_file_contains "spec/support/authentication_helpers.rb", "session_token"
    end
  end

  def test_creates_request_specs
    run_generator do
      assert_file "spec/requests/sessions_spec.rb"
      assert_file "spec/requests/users_spec.rb"
      assert_file "spec/requests/identity/email_verifications_spec.rb"
      assert_file "spec/requests/identity/password_resets_spec.rb"
      assert_file "spec/requests/settings/emails_spec.rb"
      assert_file "spec/requests/settings/passwords_spec.rb"
      assert_file "spec/requests/settings/sessions_spec.rb"
    end
  end

  def test_creates_mailer_spec
    run_generator do
      assert_file "spec/mailers/user_mailer_spec.rb"
    end
  end

  def test_does_not_create_minitest_files
    run_generator do
      refute_file "test/test_helpers/session_test_helper.rb"
      refute_file "test/controllers/sessions_controller_test.rb"
    end
  end
end

class TestFrameworkNoStarterKitTest < GeneratorTestCase
  template <<~CODE
    test_framework = "minitest"
    use_starter_kit = false
    gems_to_add = []
    <%= include "test_framework" %>
  CODE

  def test_does_not_create_test_files
    run_generator do
      refute_file "test/fixtures/users.yml"
      refute_file "test/test_helpers/session_test_helper.rb"
      refute_file ".rspec"
    end
  end
end
