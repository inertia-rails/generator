# ─── Framework-Specific Entrypoint ───────────────────────────────────

say "📦 Creating Inertia entrypoint...", :cyan

case framework
when "react"
  entrypoint_path = "#{js_destination_path}/entrypoints/inertia.#{component_ext}"
  if use_typescript
    file entrypoint_path, <%= code("react/inertia.tsx.tt") %>
  else
    file entrypoint_path, <%= code("react/inertia.jsx.tt") %>
  end
when "vue"
  entrypoint_path = "#{js_destination_path}/entrypoints/inertia.#{js_ext}"
  if use_typescript
    file entrypoint_path, <%= code("vue/inertia.ts.tt") %>
  else
    file entrypoint_path, <%= code("vue/inertia.js.tt") %>
  end
when "svelte"
  entrypoint_path = "#{js_destination_path}/entrypoints/inertia.#{js_ext}"
  if use_typescript
    file entrypoint_path, <%= code("svelte/inertia.ts.tt") %>
  else
    file entrypoint_path, <%= code("svelte/inertia.js.tt") %>
  end
end

say "  Entrypoint created: #{entrypoint_path} ✓", :green
