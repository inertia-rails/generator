# frozen_string_literal: true

require_relative "../test_helper"

class TypelizerEnabledTest < GeneratorTestCase
  template <<~CODE
    require "json"
    use_typelizer = true
    use_eslint = false
    framework = "react"
    js_destination_path = "app/javascript"
    gems_to_add = []
    eslint_ignores = []
    #{UPDATE_JSON_FILE}
    #{ADD_GEM}
    file "Gemfile", "# frozen_string_literal: true\\n"
    <%= include "typelizer" %>
  CODE

  def test_adds_gem_to_gemfile
    run_generator do |output|
      assert_file_contains "Gemfile", "typelizer"
      assert_line_printed output, "Setting up route helpers"
    end
  end
end

class TypelizerDisabledTest < GeneratorTestCase
  template <<~CODE
    use_typelizer = false
    gems_to_add = []
    eslint_ignores = []
    #{NOOP_ADD_GEM}
    <%= include "typelizer" %>
  CODE

  def test_skips_when_disabled
    run_generator do |output|
      refute_match(/Setting up route helpers/, output)
    end
  end
end
