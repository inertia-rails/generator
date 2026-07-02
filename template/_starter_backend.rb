# ─── Starter Kit Backend ──────────────────────────────────────────────

if use_starter_kit
  say "📦 Setting up Starter Kit backend...", :cyan

  # ─── Dependencies ────────────────────────────────────────────────
  gems_to_add << "bcrypt"
  gems_to_add << "authentication-zero"
  gems_to_add << {name: "letter_opener", group: :development}
  gems_to_add << {name: "capybara-lockstep", group: :test}

  # ─── Models, Controllers, Mailers, Views, Routes ───────────────
<%= copy_dir("shared/starter_backend", force: true) %>

  # ─── Migrations (need dynamic timestamps) ───────────────────────
  timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
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

  # ─── Alba Serializers (if enabled) ──────────────────────────────
  if use_alba
<%= copy_dir("shared/starter_alba", force: true) %>
  end

  say "  Starter Kit backend configured ✓", :green
end
