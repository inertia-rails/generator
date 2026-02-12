# ─── Conflict Cleanup ─────────────────────────────────────────────────

if fresh_app
  # Remove default Rails gems that Inertia+Vite replaces
  %w[importmap-rails turbo-rails stimulus-rails].each do |name|
    if gem_in_gemfile.(name)
      say "  Removing #{name}...", :yellow
      remove_gem.(name)
    end
  end

  # Remove associated files
  remove_file "config/importmap.rb"
  remove_file "bin/importmap"
  remove_file "app/javascript/controllers"
  remove_file "app/assets/stylesheets/application.css"

  # Clean layout tags
  layout_path = "app/views/layouts/application.html.erb"
  if File.exist?(layout_path)
    gsub_file layout_path, /\s*<%%=\s*javascript_importmap_tags\s*%>\s*\n/, "\n"
    gsub_file layout_path, /\s*<%%=\s*javascript_include_tag\s+["']application["'].*%>\s*\n/, "\n"
    gsub_file layout_path, /\s*<%%=\s*stylesheet_link_tag\s+["']application["'].*%>\s*\n/, "\n"
  end

  # Clean ApplicationController (Rails 8.1+)
  if File.exist?("app/controllers/application_controller.rb")
    gsub_file "app/controllers/application_controller.rb",
      /\s*# Changes to the importmap.*\n\s*stale_when_importmap_changes\n/, "\n"
  end
end
