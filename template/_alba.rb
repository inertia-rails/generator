# ─── Alba ─────────────────────────────────────────────────────────────

if use_alba
  say use_typescript ? "📦 Setting up typed serializers (Alba + Typelizer)..." : "📦 Setting up serializers (Alba)...", :cyan

  gems_to_add.push("alba", "alba-inertia")

  # When TypeScript is on, Typelizer generates types from serializers
  if use_typescript
    add_gem.("typelizer")
  end

  file "config/initializers/alba.rb", <%= code("shared/alba/config/initializers/alba.rb") %>

  file "app/serializers/application_serializer.rb", <%= code("shared/alba/app/serializers/application_serializer.rb") %>

  gsub_file "app/controllers/inertia_controller.rb",
    /class InertiaController.*\n/,
    '\0' + "  include Alba::Inertia::Controller\n"

  if use_typescript
    # When starter kit + typelizer: remove hand-written types that typelizer generates,
    # and re-export from typelizer's serializers barrel instead.
    types_index = "#{js_destination_path}/types/index.ts"
    if use_starter_kit && File.exist?(types_index)
      gsub_file types_index, /^export interface (Auth|User|Session|SharedProps) \{[^}]*\}\n\n?/m, ""
      append_with_blank_line.(types_index, "export * from \"./serializers\"\n")
    end

    eslint_ignores << "types/serializers/**"
  end

  say use_typescript ? "  Typed serializers configured ✓" : "  Serializers configured ✓", :green
end
