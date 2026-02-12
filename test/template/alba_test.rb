# frozen_string_literal: true

require_relative "../test_helper"

class AlbaWithTypescriptTest < GeneratorTestCase
  template <<~CODE
    use_alba = true
    use_typescript = true
    use_typelizer = false
    use_starter_kit = false
    use_eslint = false
    framework = "react"
    js_destination_path = "app/javascript"
    gems_to_add = []
    eslint_ignores = []
    #{ADD_GEM}
    file "app/controllers/inertia_controller.rb", <<~RUBY
      class InertiaController < ApplicationController
      end
    RUBY
    <%= include "alba" %>
  CODE

  def test_creates_initializer
    run_generator do |output|
      assert_file "config/initializers/alba.rb"
      assert_file_contains "config/initializers/alba.rb", "Alba.backend = :active_support"
      assert_line_printed output, "Setting up typed serializers"
    end
  end

  def test_creates_application_serializer_with_typelizer
    run_generator do
      assert_file "app/serializers/application_serializer.rb"
      assert_file_contains "app/serializers/application_serializer.rb", "Alba::Resource"
      assert_file_contains "app/serializers/application_serializer.rb", "Typelizer::DSL"
      assert_file_contains "app/serializers/application_serializer.rb", "Alba::Inertia::Resource"
    end
  end

  def test_adds_alba_to_inertia_controller
    run_generator do
      assert_file_contains "app/controllers/inertia_controller.rb", "Alba::Inertia::Controller"
    end
  end
end

class AlbaWithoutTypescriptTest < GeneratorTestCase
  template <<~CODE
    use_alba = true
    use_typescript = false
    use_typelizer = false
    use_starter_kit = false
    use_eslint = false
    framework = "react"
    js_destination_path = "app/javascript"
    gems_to_add = []
    #{NOOP_ADD_GEM}
    file "app/controllers/inertia_controller.rb", <<~RUBY
      class InertiaController < ApplicationController
      end
    RUBY
    <%= include "alba" %>
    file "tmp_gems.txt", gems_to_add.join(",")
  CODE

  def test_creates_initializer
    run_generator do |output|
      assert_file "config/initializers/alba.rb"
      assert_line_printed output, "Setting up serializers"
    end
  end

  def test_serializer_without_typelizer
    run_generator do
      assert_file "app/serializers/application_serializer.rb"
      assert_file_contains "app/serializers/application_serializer.rb", "Alba::Resource"
      assert_file_contains "app/serializers/application_serializer.rb", "Alba::Inertia::Resource"
      refute_file_contains "app/serializers/application_serializer.rb", "Typelizer"
    end
  end

  def test_does_not_add_typelizer_gem
    run_generator do
      assert_file_contains "tmp_gems.txt", "alba,alba-inertia"
      refute_file_contains "tmp_gems.txt", "typelizer"
    end
  end

  def test_no_typelizer_initializer
    run_generator do
      refute_file "config/initializers/typelizer.rb"
    end
  end
end

class AlbaDisabledTest < GeneratorTestCase
  template <<~CODE
    use_alba = false
    use_typescript = false
    use_typelizer = false
    gems_to_add = []
    <%= include "alba" %>
  CODE

  def test_skips_when_disabled
    run_generator do
      refute_file "config/initializers/alba.rb"
      refute_file "app/serializers/application_serializer.rb"
    end
  end
end
