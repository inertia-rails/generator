# frozen_string_literal: true

require_relative "../test_helper"

class AuthStarterKitTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_starter_kit = true
    test_framework = "minitest"
    use_alba = false
    use_teams = false
    use_typescript = true
    js_destination_path = "app/javascript"
    js_ext = "ts"
    component_ext = "tsx"
    gems_to_add = []
    npm_packages = []
    file "Gemfile", %(gem "inertia_rails", "~> 9.9"\n), force: true
    <%= include "starter_backend" %>
    gem_names = gems_to_add.map { |e| e.is_a?(Hash) ? e[:name] : e }.sort
    file "tmp_gems.txt", gem_names.join(",")
  CODE

  def test_adds_authentication_zero_after_inertia_rails
    run_generator do
      assert_file_contains "Gemfile", %(gem "inertia_rails", "~> 9.9"\n\n# An authentication system generator)
    end
  end

  def test_creates_models
    run_generator do
      assert_file "app/models/user.rb"
      assert_file "app/models/session.rb"
      assert_file "app/models/current.rb"
    end
  end

  def test_creates_controllers
    run_generator do
      assert_file "app/controllers/sessions_controller.rb"
      assert_file "app/controllers/users_controller.rb"
      assert_file "app/controllers/dashboard_controller.rb"
      assert_file "app/controllers/home_controller.rb"
      assert_file "app/controllers/settings/profiles_controller.rb"
      assert_file "app/controllers/settings/passwords_controller.rb"
      assert_file "app/controllers/settings/emails_controller.rb"
      assert_file "app/controllers/settings/sessions_controller.rb"
      assert_file "app/controllers/identity/email_verifications_controller.rb"
      assert_file "app/controllers/identity/password_resets_controller.rb"
    end
  end

  def test_rate_limits_authentication_endpoints
    run_generator do
      {
        "sessions_controller.rb" => "only: :create",
        "users_controller.rb" => "only: :create",
        "identity/password_resets_controller.rb" => "only: %i[create update]",
        "settings/passwords_controller.rb" => "only: :update"
      }.each do |controller, actions|
        assert_file_contains "app/controllers/#{controller}", "rate_limit to: 10, within: 3.minutes, #{actions}"
      end
    end
  end

  def test_creates_migrations
    run_generator do
      migrations = Dir.glob("#{destination}/db/migrate/*")
      assert migrations.any? { |f| f.include?("create_users") }, "Missing create_users migration"
      assert migrations.any? { |f| f.include?("create_sessions") }, "Missing create_sessions migration"
    end
  end

  def test_creates_mailers
    run_generator do
      assert_file "app/mailers/user_mailer.rb"
      assert_file "app/views/user_mailer/email_verification.html.erb"
      assert_file "app/views/user_mailer/password_reset.html.erb"
    end
  end

  def test_creates_routes
    run_generator do
      assert_file "config/routes.rb"
    end
  end

  def test_adds_bcrypt_gem
    run_generator do
      assert_file_contains "tmp_gems.txt", "bcrypt"
      refute_file_contains "tmp_gems.txt", "typelizer"
    end
  end
end

class AuthStarterKitWithAlbaTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_starter_kit = true
    test_framework = "minitest"
    use_alba = true
    use_teams = false
    use_typescript = true
    js_destination_path = "app/javascript"
    js_ext = "ts"
    component_ext = "tsx"
    gems_to_add = []
    npm_packages = []
    <%= include "starter_backend" %>
  CODE

  def test_creates_alba_serializers
    run_generator do
      assert_file "app/serializers/shared_props_serializer.rb"
      assert_file "app/serializers/auth_serializer.rb"
      assert_file "app/serializers/user_serializer.rb"
      assert_file "app/serializers/session_serializer.rb"
      assert_file "app/serializers/identity/password_resets_edit_serializer.rb"
      assert_file "app/serializers/settings/sessions_index_serializer.rb"
    end
  end
end

class AuthStarterKitWithTeamsTest < GeneratorTestCase
  template AuthStarterKitTest.template_contents.sub("use_teams = false", "use_teams = true")

  def test_adds_teams
    run_generator do
      assert_file_contains "Gemfile", %(gem "authentication-zero"\n\n# Authorization framework)
      assert_file "app/policies/team_policy.rb"
      assert_file "db/migrate/20250801153829_create_teams.rb"
      assert_file_contains "app/models/user.rb", "include HasTeams"
      assert_file_contains "config/routes.rb", %(scope ":team_slug", as: :team do)
    end
  end
end

class AuthDisabledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    framework = "react"
    use_starter_kit = false
    test_framework = "minitest"
    use_alba = false
    use_teams = false
    use_typescript = true
    js_destination_path = "app/javascript"
    js_ext = "ts"
    component_ext = "tsx"
    gems_to_add = []
    npm_packages = []
    <%= include "starter_backend" %>
  CODE

  def test_skips_when_not_starter_kit
    run_generator do
      refute_file "app/models/user.rb"
      refute_file "app/controllers/sessions_controller.rb"
      refute_file "app/mailers/user_mailer.rb"
    end
  end
end
