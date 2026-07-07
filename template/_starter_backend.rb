# ─── Starter Kit Backend ──────────────────────────────────────────────

if use_starter_kit
  say "📦 Setting up Starter Kit backend...", :cyan

  # ─── Dependencies ────────────────────────────────────────────────
  # Prefer editing the Gemfile in place (uncomment/insert at the Rails
  # anchors); fall back to appending when an anchor is missing.
  gemfile_body = File.exist?("Gemfile") ? File.read("Gemfile") : ""

  if gemfile_body.match?(/^# gem "bcrypt"/)
    uncomment_lines "Gemfile", /gem "bcrypt"/
  else
    gems_to_add << "bcrypt"
  end

  inertia_gem_anchor = "gem \"inertia_rails\", \"~> 3.21\"\n"
  if gemfile_body.include?(inertia_gem_anchor)
    insert_into_file "Gemfile",
      "\n# An authentication system generator for Rails applications\n# we leave gem here to watch for security updates\ngem \"authentication-zero\"\n",
      after: inertia_gem_anchor
  else
    gems_to_add << "authentication-zero"
  end

  web_console_anchor = "  # Use console on exceptions pages [https://github.com/rails/web-console]\n  gem \"web-console\"\n"
  if gemfile_body.include?(web_console_anchor)
    insert_into_file "Gemfile",
      "\n  # Use letter_opener to preview emails in the browser in development [https://github.com/ryanb/letter_opener]\n  gem \"letter_opener\"\n",
      after: web_console_anchor
  else
    gems_to_add << {name: "letter_opener", group: :development}
  end

  # The starter kit uses no Active Storage variants — keep image_processing
  # commented out (Rails 8.1 generates it enabled).
  gsub_file "Gemfile", /^gem "image_processing", "~> 1\.2"$/,
    "# gem \"image_processing\", \"~> 1.2\""

  # ─── Models, Controllers, Mailers, Views, Routes ───────────────
<%= copy_dir("shared/starter_backend", force: true) %>

  # ─── Migrations (fixed timestamps: output must be deterministic) ─
  # A Time.now stamp made every generation differ, which forced the starter-kit
  # sync to skip db/ entirely. New starter migrations get the next stamp in order.
  timestamp = "20250801153827"
  file "db/migrate/#{timestamp}_create_users.rb", <%= code("shared/starter/migrations/create_users.rb") %>
  file "db/migrate/#{timestamp.to_i + 1}_create_sessions.rb", <%= code("shared/starter/migrations/create_sessions.rb") %>

  # ─── Preview emails in the browser in development (letter_opener) ─
  dev_env = "config/environments/development.rb"
  mailer_anchor = "config.action_mailer.default_url_options = { host: \"localhost\", port: 3000 }\n"
  if File.exist?(dev_env) && File.read(dev_env).include?(mailer_anchor) &&
      !File.read(dev_env).include?("delivery_method = :letter_opener")
    insert_into_file dev_env,
      "\n  config.action_mailer.delivery_method = :letter_opener\n\n  config.action_mailer.perform_deliveries = true\n",
      after: mailer_anchor
  end

  # Keep generated code omakase-clean by autocorrecting after `rails generate`.
  if File.exist?(dev_env)
    gsub_file dev_env,
      "# config.generators.apply_rubocop_autocorrect_after_generate!",
      "config.generators.apply_rubocop_autocorrect_after_generate!"
  end

  # ─── Explicit framework requires (instead of rails/all) ──────────
  app_rb = "config/application.rb"
  if File.exist?(app_rb) && File.read(app_rb).include?("require \"rails/all\"\n")
    test_unit_require = (test_framework == "rspec") ?
      "# require \"rails/test_unit/railtie\"" : "require \"rails/test_unit/railtie\""
    gsub_file app_rb, "require \"rails/all\"\n", <<~RUBY
      require "rails"
      # Pick the frameworks you want:
      require "active_model/railtie"
      require "active_job/railtie"
      require "active_record/railtie"
      require "active_storage/engine"
      require "action_controller/railtie"
      require "action_mailer/railtie"
      require "action_mailbox/engine"
      require "action_text/engine"
      require "action_view/railtie"
      require "action_cable/engine"
      #{test_unit_require}
    RUBY
  end

  # RSpec owns test generation — stop Rails generators from emitting
  # minitest system-test files.
  if test_framework == "rspec" && File.exist?(app_rb) &&
      !File.read(app_rb).include?("config.generators.system_tests")
    insert_into_file app_rb,
      "\n    # Don't generate system test files.\n    config.generators.system_tests = nil\n",
      before: /^  end\nend\n/
  end

  # ─── Rakefile: run RuboCop autocorrect as the default task ────────
  if File.exist?("Rakefile") && !File.read("Rakefile").include?("RuboCop::RakeTask")
    append_to_file "Rakefile", <<~RUBY

      if Rails.env.local?
        require "rubocop/rake_task"
        RuboCop::RakeTask.new

        task default: %i[rubocop:autocorrect]
      end
    RUBY
  end

  # ─── Alba Serializers (if enabled) ──────────────────────────────
  if use_alba
<%= copy_dir("shared/starter_alba", force: true) %>
  end

  say "  Starter Kit backend configured ✓", :green
end
