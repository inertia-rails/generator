# ─── Test Framework ───────────────────────────────────────────────────

if test_framework == "rspec"
  say "📦 Setting up RSpec...", :cyan

  gems_to_add << {name: "rspec-rails", group: %i[development test]}

  say "  RSpec will be installed ✓", :green
end

if use_starter_kit
  say "📦 Setting up starter kit tests (#{test_framework})...", :cyan

  # ─── Fixtures (shared between minitest and rspec) ────────────────
<%= copy_dir("shared/starter_test_fixtures", force: true) %>

  # ─── Minitest files ──────────────────────────────────────────────
  if test_framework == "minitest"
<%= copy_dir("shared/starter_test_minitest", force: true) %>

    # Add session helper require to test_helper.rb
    if File.exist?("test/test_helper.rb")
      insert_into_file "test/test_helper.rb",
        "\nrequire_relative \"test_helpers/session_test_helper\"\n",
        after: "require \"rails/test_help\"\n"

      insert_into_file "test/test_helper.rb",
        "\nclass ActiveSupport::TestCase\n  include SessionTestHelper\nend\n",
        before: /\z/
    end

    say "  Minitest files created ✓", :green
  end

  # ─── RSpec files ─────────────────────────────────────────────────
  if test_framework == "rspec"
    file ".rspec", "--require spec_helper\n", force: true
<%= copy_dir("shared/starter_test_rspec", force: true) %>

    say "  RSpec files created ✓", :green
  end
end
