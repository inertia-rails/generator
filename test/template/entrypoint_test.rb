# frozen_string_literal: true

require_relative "../test_helper"

class EntrypointReactTsTest < GeneratorTestCase
  template <<~CODE
    framework = "react"
    use_typescript = true
    js_ext = "ts"
    component_ext = "tsx"
    js_destination_path = "app/javascript"
    <%= include "inertia_entrypoint" %>
  CODE

  def test_creates_tsx_entrypoint
    run_generator do |output|
      assert_file "app/javascript/entrypoints/inertia.tsx"
      assert_file_contains "app/javascript/entrypoints/inertia.tsx", "createInertiaApp"
      assert_file_contains "app/javascript/entrypoints/inertia.tsx", "@inertiajs/react"
      assert_file_contains "app/javascript/entrypoints/inertia.tsx", "strictMode: true"
      assert_line_printed output, "Creating Inertia entrypoint"
    end
  end
end

class EntrypointReactJsTest < GeneratorTestCase
  template <<~CODE
    framework = "react"
    use_typescript = false
    js_ext = "js"
    component_ext = "jsx"
    js_destination_path = "app/javascript"
    <%= include "inertia_entrypoint" %>
  CODE

  def test_creates_jsx_entrypoint
    run_generator do |output|
      assert_file "app/javascript/entrypoints/inertia.jsx"
      assert_file_contains "app/javascript/entrypoints/inertia.jsx", "createInertiaApp"
      assert_file_contains "app/javascript/entrypoints/inertia.jsx", "@inertiajs/react"
      assert_line_printed output, "Creating Inertia entrypoint"
    end
  end
end

class EntrypointVueTsTest < GeneratorTestCase
  template <<~CODE
    framework = "vue"
    use_typescript = true
    js_ext = "ts"
    component_ext = "vue"
    js_destination_path = "app/javascript"
    <%= include "inertia_entrypoint" %>
  CODE

  def test_creates_ts_entrypoint
    run_generator do |output|
      assert_file "app/javascript/entrypoints/inertia.ts"
      assert_file_contains "app/javascript/entrypoints/inertia.ts", "createInertiaApp"
      assert_file_contains "app/javascript/entrypoints/inertia.ts", "@inertiajs/vue3"
      assert_file_contains "app/javascript/entrypoints/inertia.ts", "pages"
      assert_line_printed output, "Creating Inertia entrypoint"
    end
  end
end

class EntrypointVueJsTest < GeneratorTestCase
  template <<~CODE
    framework = "vue"
    use_typescript = false
    js_ext = "js"
    component_ext = "vue"
    js_destination_path = "app/javascript"
    <%= include "inertia_entrypoint" %>
  CODE

  def test_creates_js_entrypoint
    run_generator do |output|
      assert_file "app/javascript/entrypoints/inertia.js"
      assert_file_contains "app/javascript/entrypoints/inertia.js", "createInertiaApp"
      assert_file_contains "app/javascript/entrypoints/inertia.js", "@inertiajs/vue3"
      assert_line_printed output, "Creating Inertia entrypoint"
    end
  end
end

class EntrypointSvelteTsTest < GeneratorTestCase
  template <<~CODE
    framework = "svelte"
    use_typescript = true
    js_ext = "ts"
    component_ext = "svelte"
    js_destination_path = "app/javascript"
    <%= include "inertia_entrypoint" %>
  CODE

  def test_creates_ts_entrypoint
    run_generator do |output|
      assert_file "app/javascript/entrypoints/inertia.ts"
      assert_file_contains "app/javascript/entrypoints/inertia.ts", "createInertiaApp"
      assert_file_contains "app/javascript/entrypoints/inertia.ts", "@inertiajs/svelte"
      assert_file_contains "app/javascript/entrypoints/inertia.ts", "pages"
      assert_line_printed output, "Creating Inertia entrypoint"
    end
  end
end

class EntrypointSvelteJsTest < GeneratorTestCase
  template <<~CODE
    framework = "svelte"
    use_typescript = false
    js_ext = "js"
    component_ext = "svelte"
    js_destination_path = "app/javascript"
    <%= include "inertia_entrypoint" %>
  CODE

  def test_creates_js_entrypoint
    run_generator do |output|
      assert_file "app/javascript/entrypoints/inertia.js"
      assert_file_contains "app/javascript/entrypoints/inertia.js", "createInertiaApp"
      assert_file_contains "app/javascript/entrypoints/inertia.js", "@inertiajs/svelte"
      assert_line_printed output, "Creating Inertia entrypoint"
    end
  end
end
