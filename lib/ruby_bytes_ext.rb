# frozen_string_literal: true

require "rbytes"

module RubyBytes
  # Upstream rbytes' `code(path)` interpolates file contents into a heredoc,
  # producing `...end\n\n  TCODE` — the file's own `\n` plus the source `\n`
  # before the terminator. That leaves every generated file with a trailing
  # blank line, which breaks Rails 8's Layout/TrailingEmptyLines rubocop rule.
  module CompilerTrimTrailingNewline
    def code(path)
      super.sub(/\n(\n  TCODE\n)/, '\1')
    end
  end
  Compiler.prepend(CompilerTrimTrailingNewline)

  class Compiler
    # Short commit SHA of the build being compiled, stamped into the template
    # so bug reports can say which build ran. CI provides it via GITHUB_SHA;
    # local builds are "dev" because the working tree may not match any commit.
    def template_version
      sha = ENV["GITHUB_SHA"].to_s
      sha.empty? ? "dev" : sha[0, 8]
    end

    # Generate `file` statements for every file under a source directory.
    #
    # At compile time, walks `source_dir` (relative to template root) and
    # produces one `file` statement per file with inlined content.
    #
    # When `dest_var` is given, paths are prefixed with a runtime variable:
    #   <%= copy_dir("react/starter", "js_destination_path", force: true) %>
    #   # => file "#{js_destination_path}/components/app-sidebar.tsx", ..., force: true
    #
    # When `dest_var` is omitted, relative paths are used as-is (source dir
    # should mirror the target directory structure):
    #   <%= copy_dir("shared/starter_backend", force: true) %>
    #   # => file "app/models/user.rb", ..., force: true
    #
    def copy_dir(source_dir, dest_var = nil, force: false)
      files = Dir.glob("#{source_dir}/**/*", base: root)
        .select { |f| File.file?(File.join(root, f)) }
        .sort

      force_opt = force ? ", force: true" : ""
      files.map do |path|
        relative = path.delete_prefix("#{source_dir}/").delete_suffix(".tt")
        dest = dest_var ? "\"\#{#{dest_var}}/#{relative}\"" : "\"#{relative}\""
        "    file #{dest}, #{code(path)}#{force_opt}"
      end.join("\n")
    end
  end
end
