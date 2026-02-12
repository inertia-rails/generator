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

  # ─── Alba Serializers (if enabled) ──────────────────────────────
  if use_alba
<%= copy_dir("shared/starter_alba", force: true) %>
  end

  say "  Starter Kit backend configured ✓", :green
end
