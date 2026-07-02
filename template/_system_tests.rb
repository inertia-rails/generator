# ─── System Tests (Capybara + capybara-lockstep) ─────────────────────

if use_system_tests
  say "📦 Setting up system tests...", :cyan

  # ─── Gems ──────────────────────────────────────────────────────────
  # `rails new` provides capybara + selenium-webdriver in the :test group
  # unless it ran with --skip-system-test; slot capybara-lockstep next to
  # them, or add all three when the group is missing.
  gemfile_content = File.exist?("Gemfile") ? File.read("Gemfile") : ""
  capybara_anchor = "  gem \"capybara\"\n"
  if gemfile_content.include?(capybara_anchor)
    unless gemfile_content.include?("capybara-lockstep")
      insert_into_file "Gemfile",
        "  # Synchronize Capybara commands with application JavaScript and AJAX requests\n  gem \"capybara-lockstep\"\n",
        after: capybara_anchor
    end
  else
    gems_to_add << {name: "capybara", group: :test}
    gems_to_add << {name: "selenium-webdriver", group: :test}
    gems_to_add << {name: "capybara-lockstep", group: :test}
  end

  # ─── capybara-lockstep helper tag ──────────────────────────────────
  # Syncs Capybara with in-flight Inertia/AJAX requests. Only active in
  # the test environment (the gem lives in the :test group).
  layout_file = "app/views/layouts/application.html.erb"
  csrf_anchor = "    <%%= csrf_meta_tags %>\n"
  if File.exist?(layout_file) && File.read(layout_file).include?(csrf_anchor) &&
      !File.read(layout_file).include?("capybara_lockstep")
    insert_into_file layout_file,
      "    <%%= capybara_lockstep if defined?(Capybara::Lockstep) %>\n",
      before: csrf_anchor
  end

  # ─── Driver configuration ──────────────────────────────────────────
  if test_framework == "rspec"
    rails_helper = "spec/rails_helper.rb"
    if File.exist?(rails_helper)
      unless File.read(rails_helper).include?("capybara/rspec")
        insert_into_file rails_helper,
          "require \"capybara/rspec\"\nrequire \"selenium-webdriver\"\n",
          after: "require \"rspec/rails\"\n"
      end
      unless File.read(rails_helper).include?("driven_by")
        insert_into_file rails_helper,
          "  config.before(type: :system) do\n    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]\n  end\n\n",
          before: "  config.include ActiveSupport::Testing::TimeHelpers\n"
      end
    end
  elsif File.exist?("test/test_helper.rb") && !File.exist?("test/application_system_test_case.rb")
    # `rails new` ran with --skip-system-test — recreate the Rails default
    file "test/application_system_test_case.rb", <<~RUBY
      require "test_helper"

      class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
        driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
      end
    RUBY
  end

  # ─── Example system test (starter kit) ─────────────────────────────
  if use_starter_kit
    if test_framework == "rspec"
      file "spec/system/sessions_spec.rb", <%= code("shared/starter_system/sessions_spec.rb") %>
    else
      file "test/system/sessions_test.rb", <%= code("shared/starter_system/sessions_test.rb") %>
    end
  end

  say "  System tests configured ✓", :green
end
