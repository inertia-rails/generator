# ─── Welcome Page ────────────────────────────────────────────────────

# Skip example page if starter kit provides its own pages
unless use_starter_kit
  say "📦 Creating welcome page...", :cyan

  file "app/controllers/home_controller.rb", <%= code("shared/example/home_controller.rb") %>

  routes_content = File.read("config/routes.rb")
  unless routes_content.match?(/^\s*root\s+/)
    route 'root "home#index"'
  end

  case framework
  when "react"
    file "#{js_destination_path}/pages/home/index.#{component_ext}", <%= code("react/home.tsx") %>
  when "vue"
    file "#{js_destination_path}/pages/home/index.vue", <%= code("vue/home.vue") %>
  when "svelte"
    file "#{js_destination_path}/pages/home/index.svelte", <%= code("svelte/home.svelte") %>
  end

  say "  Welcome page created ✓", :green
end
