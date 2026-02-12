# frozen_string_literal: true

require_relative "../test_helper"

class StarterFrontendReactTest < GeneratorTestCase
  template <<~'CODE'
    framework = "react"
    use_starter_kit = true
    use_shadcn = true
    use_alba = false
    js_destination_path = "app/javascript"
    js_ext = "ts"
    component_ext = "tsx"
    npm_packages = []
    npm_dev_packages = []
    <%= include "starter_frontend" %>
    say "NPM=#{npm_packages.sort.join(",")}"
  CODE

  def test_creates_entrypoint
    run_generator do
      assert_file "app/javascript/entrypoints/inertia.tsx"
    end
  end

  def test_creates_types
    run_generator do
      assert_file "app/javascript/types/index.ts"
    end
  end

  def test_creates_utils
    run_generator do
      assert_file "app/javascript/lib/utils.ts"
    end
  end

  def test_creates_hooks
    run_generator do
      assert_file "app/javascript/hooks/use-appearance.tsx"
      assert_file "app/javascript/hooks/use-flash.tsx"
      assert_file "app/javascript/hooks/use-initials.tsx"
      assert_file "app/javascript/hooks/use-mobile.ts"
    end
  end

  def test_creates_layouts
    run_generator do
      assert_file "app/javascript/layouts/persistent-layout.tsx"
      assert_file "app/javascript/layouts/app-layout.tsx"
      assert_file "app/javascript/layouts/auth-layout.tsx"
      assert_file "app/javascript/layouts/settings/layout.tsx"
      assert_file "app/javascript/layouts/app/app-sidebar-layout.tsx"
      assert_file "app/javascript/layouts/auth/auth-card-layout.tsx"
    end
  end

  def test_creates_components
    run_generator do
      assert_file "app/javascript/components/app-sidebar.tsx"
      assert_file "app/javascript/components/nav-user.tsx"
      assert_file "app/javascript/components/breadcrumbs.tsx"
      assert_file "app/javascript/components/delete-user.tsx"
    end
  end

  def test_creates_pages
    run_generator do
      assert_file "app/javascript/pages/dashboard/index.tsx"
      assert_file "app/javascript/pages/sessions/new.tsx"
      assert_file "app/javascript/pages/users/new.tsx"
      assert_file "app/javascript/pages/settings/profiles/show.tsx"
      assert_file "app/javascript/pages/settings/passwords/show.tsx"
      assert_file "app/javascript/pages/identity/password_resets/new.tsx"
    end
  end

  def test_adds_npm_packages
    run_generator do |output|
      assert_line_printed output, "@headlessui/react"
    end
  end
end

class StarterFrontendVueTest < GeneratorTestCase
  template <<~CODE
    framework = "vue"
    use_starter_kit = true
    use_shadcn = true
    use_alba = false
    js_destination_path = "app/javascript"
    js_ext = "ts"
    component_ext = "vue"
    npm_packages = []
    npm_dev_packages = []
    <%= include "starter_frontend" %>
  CODE

  def test_creates_vue_components
    run_generator do
      assert_file "app/javascript/components/AppSidebar.vue"
      assert_file "app/javascript/components/NavUser.vue"
      assert_file "app/javascript/components/Breadcrumbs.vue"
      assert_file "app/javascript/components/ResourceItem.vue"
    end
  end

  def test_creates_vue_composables
    run_generator do
      assert_file "app/javascript/composables/useAppearance.ts"
      assert_file "app/javascript/composables/useFlash.ts"
      assert_file "app/javascript/composables/useInitials.ts"
    end
  end

  def test_creates_vue_layouts
    run_generator do
      assert_file "app/javascript/layouts/PersistentLayout.vue"
      assert_file "app/javascript/layouts/AppLayout.vue"
      assert_file "app/javascript/layouts/AuthLayout.vue"
    end
  end
end

class StarterFrontendSvelteTest < GeneratorTestCase
  template <<~CODE
    framework = "svelte"
    use_starter_kit = true
    use_shadcn = true
    use_alba = false
    js_destination_path = "app/javascript"
    js_ext = "ts"
    component_ext = "svelte"
    npm_packages = []
    npm_dev_packages = []
    <%= include "starter_frontend" %>
  CODE

  def test_creates_svelte_components
    run_generator do
      assert_file "app/javascript/components/app-sidebar.svelte"
      assert_file "app/javascript/components/nav-user.svelte"
      assert_file "app/javascript/components/resource-item.svelte"
    end
  end

  def test_creates_svelte_runes
    run_generator do
      assert_file "app/javascript/runes/use-appearance.svelte.ts"
      assert_file "app/javascript/runes/use-flash.svelte.ts"
      assert_file "app/javascript/runes/use-initials.ts"
    end
  end

  def test_creates_svelte_utils
    run_generator do
      assert_file "app/javascript/utils.ts"
    end
  end
end

class StarterFrontendDisabledTest < GeneratorTestCase
  template <<~CODE
    framework = "react"
    use_starter_kit = false
    use_shadcn = false
    use_alba = false
    js_destination_path = "app/javascript"
    js_ext = "ts"
    component_ext = "tsx"
    npm_packages = []
    npm_dev_packages = []
    <%= include "starter_frontend" %>
  CODE

  def test_skips_when_not_starter_kit
    run_generator do
      refute_file "app/javascript/pages/dashboard/index.tsx"
      refute_file "app/javascript/layouts/app-layout.tsx"
      refute_file "app/javascript/components/app-sidebar.tsx"
    end
  end
end
