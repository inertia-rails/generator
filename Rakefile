# frozen_string_literal: true

require "rake/testtask"

$LOAD_PATH.unshift File.expand_path("lib", __dir__)

require_relative "test/support/e2e_helpers"

EXCLUDED_TESTS = %w[test/e2e_test.rb test/matrix_test.rb].freeze

Rake::TestTask.new do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"].exclude(*EXCLUDED_TESTS)
  t.warning = false
end

namespace :test do
  task :isolated do
    excluded = EXCLUDED_TESTS.map { |f| File.expand_path(f) }
    Dir.glob("test/**/*_test.rb").reject { |f| excluded.include?(File.expand_path(f)) }.all? do |file|
      sh(Gem.ruby, "-I#{__dir__}/lib:#{__dir__}/test", file)
    end || raise("Failures")
  end

  desc "Run end-to-end tests (slow — runs rails new with compiled template)"
  task :e2e do
    sh(Gem.ruby, "-Ilib:test", "test/e2e_test.rb")
  end
end

desc "Generate installation template"
task :compile do
  require "ruby_bytes/cli"
  require "ruby_bytes_ext"
  RubyBytes::CLI.new.run("compile", E2eHelpers::TEMPLATE_ROOT)
end

STARTER_COMMON_ENV = {
  "INERTIA_TEST_FRAMEWORK" => "minitest",
  "INERTIA_ALBA" => "0",
  "BUNDLE_IGNORE_MESSAGES" => "1"
}.freeze

STARTER_CONFIGS = {
  react: STARTER_COMMON_ENV.merge(
    "INERTIA_FRAMEWORK" => "react",
    "INERTIA_STARTER_KIT" => "1"
  ),
  vue: STARTER_COMMON_ENV.merge(
    "INERTIA_FRAMEWORK" => "vue",
    "INERTIA_STARTER_KIT" => "1"
  ),
  svelte: STARTER_COMMON_ENV.merge(
    "INERTIA_FRAMEWORK" => "svelte",
    "INERTIA_STARTER_KIT" => "1"
  )
}.freeze

namespace :starter do
  def generate_starter(framework, env)
    require "open3"

    compiled = E2eHelpers.compile_template(File.join(Dir.tmpdir, "inertia_starter_template.rb"))

    app_name = "#{framework}-starter-kit"
    dest = File.expand_path("tmp/#{app_name}")
    FileUtils.rm_rf(dest)
    FileUtils.mkdir_p("tmp")

    cmd = ["rails", "new", app_name, "-m", compiled, *E2eHelpers::STARTER_KIT_FLAGS]

    puts "Generating #{framework} starter kit in tmp/#{app_name}..."

    stdout, stderr, status = Bundler.with_original_env do
      Open3.capture3(env, *cmd, chdir: File.expand_path("tmp"))
    end

    unless status.success?
      warn "#{stdout}\n#{stderr}"
      raise "Failed to generate #{framework} starter kit (exit #{status.exitstatus})"
    end

    puts "#{framework} starter kit generated in tmp/#{app_name}"
  end

  %i[react vue svelte].each do |fw|
    desc "Generate #{fw} starter kit app in tmp/#{fw}-starter-kit/"
    task fw do
      generate_starter(fw, STARTER_CONFIGS[fw])
    end
  end

  desc "Generate all starter kit apps"
  task all: %i[react vue svelte]
end

desc "Run detect + prompts (no mutations). Use APP=path for existing app, otherwise creates a fresh one."
task :detect do
  require "ruby_bytes/compiler"
  require "ruby_bytes_ext"
  require "tmpdir"

  compiled = RubyBytes::Compiler.new(File.expand_path(E2eHelpers::TEMPLATE_ROOT)).render
  # Inject exit(0) after detect + prompts, before any mutations
  marker = "# ─── Phase 2: Core Infrastructure"
  unless compiled.sub!(marker, <<~RUBY + marker)
    say "\\n✅ Detect + prompts finished (no changes made). Exiting early.", :green
    exit(0)

  RUBY
    abort "Could not find '#{marker}' in compiled template"
  end

  template_path = File.join(Dir.tmpdir, "inertia_detect_only.rb")
  File.write(template_path, compiled)

  require "bundler"

  if ENV["APP"]
    app_dir = File.expand_path(ENV["APP"])
    abort "APP=#{ENV["APP"]} not found" unless File.directory?(app_dir)
    puts "Running detect + prompts against existing app: #{app_dir}\n\n"
    Bundler.with_original_env do
      system("bin/rails", "app:template", "LOCATION=#{template_path}", chdir: app_dir) || abort("Failed")
    end
  else
    dest = File.expand_path("tmp/detect_test_app")
    FileUtils.rm_rf(dest)
    FileUtils.mkdir_p("tmp")

    cmd = %w[rails new detect_test_app -m] + [template_path] + E2eHelpers::RAILS_FLAGS

    puts "Running detect + prompts against a fresh Rails app...\n\n"
    Bundler.with_original_env do
      system(*cmd, chdir: File.expand_path("tmp")) || abort("Failed")
    end
  end
end

desc "Run Standard Ruby linter"
task :lint do
  sh "bundle exec standardrb"
end

desc "Run Standard Ruby linter with auto-fix"
task "lint:fix" do
  sh "bundle exec standardrb --fix"
end

task default: %w[compile test:isolated lint]
