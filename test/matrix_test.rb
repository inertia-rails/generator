#!/usr/bin/env ruby
# frozen_string_literal: true

# One-shot prerelease matrix validation.
#
# Usage:
#   ruby test/matrix_test.rb                  # Run round 1 (6 configs)
#   ruby test/matrix_test.rb --round 2        # Run rounds 1-2 (15 configs)
#   ruby test/matrix_test.rb --round 3        # Run rounds 1-3 (24 configs)
#   ruby test/matrix_test.rb --round 4        # All rounds (27 configs)
#   ruby test/matrix_test.rb --only react_max # Re-run one config
#   ruby test/matrix_test.rb --concurrency 6  # Parallel workers (default: 4)
#   ruby test/matrix_test.rb --keep           # Keep generated apps for inspection

require "bundler/setup"
require "open3"
require "fileutils"
require "json"
require "tmpdir"
require "optparse"
require "net/http"
require "uri"

require_relative "support/e2e_helpers"

RESULTS_DIR = File.expand_path("../tmp/matrix_results", __dir__)

# ─── Configuration Matrix ──────────────────────────────────────────

COMMON_ENV = E2eHelpers::COMMON_ENV.merge("BUNDLE_IGNORE_MESSAGES" => "1").freeze
RAILS_FLAGS = E2eHelpers::RAILS_FLAGS
FOUNDATION_FLAGS = E2eHelpers::FOUNDATION_FLAGS

def foundation(framework, **overrides)
  base = {
    "INERTIA_FRAMEWORK" => framework,
    "INERTIA_STARTER_KIT" => "0",
    "INERTIA_TS" => "0",
    "INERTIA_TAILWIND" => "0",
    "INERTIA_SHADCN" => "0",
    "INERTIA_ESLINT" => "0",
    "INERTIA_SSR" => "0",
    "INERTIA_TYPELIZER" => "0",
    "INERTIA_ALBA" => "0"
  }
  overrides.each { |k, v| base[k.to_s] = v.to_s }
  base
end

def starter(framework)
  {
    "INERTIA_FRAMEWORK" => framework,
    "INERTIA_STARTER_KIT" => "1",
    "INERTIA_TYPELIZER" => "1"
  }
end

# Round 1: Extremes per framework (most likely to catch bugs)
ROUND_1 = {
  "react_min" => foundation("react"),
  "react_max" => foundation("react",
    INERTIA_TS: 1, INERTIA_TAILWIND: 1, INERTIA_SHADCN: 1,
    INERTIA_ESLINT: 1, INERTIA_SSR: 1, INERTIA_TYPELIZER: 1, INERTIA_ALBA: 1),
  "vue_min" => foundation("vue"),
  "vue_max" => foundation("vue",
    INERTIA_TS: 1, INERTIA_TAILWIND: 1, INERTIA_SHADCN: 1,
    INERTIA_ESLINT: 1, INERTIA_SSR: 1, INERTIA_TYPELIZER: 1, INERTIA_ALBA: 1),
  "svelte_min" => foundation("svelte"),
  "svelte_max" => foundation("svelte",
    INERTIA_TS: 1, INERTIA_TAILWIND: 1, INERTIA_SHADCN: 1,
    INERTIA_ESLINT: 1, INERTIA_SSR: 1, INERTIA_TYPELIZER: 1, INERTIA_ALBA: 1)
}.freeze

# Round 2: Tricky feature boundaries
ROUND_2 = {
  # TS + Tailwind but NO shadcn (shadcn boundary)
  "react_ts_tw_noshadcn" => foundation("react", INERTIA_TS: 1, INERTIA_TAILWIND: 1),
  "vue_ts_tw_noshadcn" => foundation("vue", INERTIA_TS: 1, INERTIA_TAILWIND: 1),
  "svelte_ts_tw_noshadcn" => foundation("svelte", INERTIA_TS: 1, INERTIA_TAILWIND: 1),
  # TS without Tailwind (alba works, shadcn impossible)
  "react_ts_notw" => foundation("react", INERTIA_TS: 1, INERTIA_ALBA: 1),
  "vue_ts_notw" => foundation("vue", INERTIA_TS: 1, INERTIA_ALBA: 1),
  "svelte_ts_notw" => foundation("svelte", INERTIA_TS: 1, INERTIA_ALBA: 1),
  # JS + Tailwind (no TS)
  "react_js_tw" => foundation("react", INERTIA_TAILWIND: 1),
  "vue_js_tw" => foundation("vue", INERTIA_TAILWIND: 1),
  "svelte_js_tw" => foundation("svelte", INERTIA_TAILWIND: 1),
  # JS + Tailwind + shadcn (no TS)
  "react_js_tw_shadcn" => foundation("react", INERTIA_TAILWIND: 1, INERTIA_SHADCN: 1),
  "vue_js_tw_shadcn" => foundation("vue", INERTIA_TAILWIND: 1, INERTIA_SHADCN: 1),
  "svelte_js_tw_shadcn" => foundation("svelte", INERTIA_TAILWIND: 1, INERTIA_SHADCN: 1)
}.freeze

# Round 3: Additive features (ESLint, SSR, typelizer toggles)
ROUND_3 = {
  # ESLint alone (no TS, no Tailwind)
  "react_eslint_only" => foundation("react", INERTIA_ESLINT: 1),
  "vue_eslint_only" => foundation("vue", INERTIA_ESLINT: 1),
  "svelte_eslint_only" => foundation("svelte", INERTIA_ESLINT: 1),
  # SSR alone
  "react_ssr_only" => foundation("react", INERTIA_SSR: 1),
  "vue_ssr_only" => foundation("vue", INERTIA_SSR: 1),
  "svelte_ssr_only" => foundation("svelte", INERTIA_SSR: 1),
  # typelizer alone
  "react_typelizer_only" => foundation("react", INERTIA_TYPELIZER: 1),
  "vue_typelizer_only" => foundation("vue", INERTIA_TYPELIZER: 1),
  "svelte_typelizer_only" => foundation("svelte", INERTIA_TYPELIZER: 1)
}.freeze

# Round 4: Starter kits
ROUND_4 = {
  "react_starter" => starter("react"),
  "vue_starter" => starter("vue"),
  "svelte_starter" => starter("svelte")
}.freeze

# Round 5: Coverage gaps (rspec, alba+starter, ESLint+typelizer interaction)
ROUND_5 = {
  # rspec (never tested — only affects Gemfile + test dir structure)
  "react_rspec" => foundation("react", INERTIA_TEST_FRAMEWORK: "rspec"),
  # alba + starter kit (different controller branches: serializers vs inline render)
  "react_starter_alba" => starter("react").merge("INERTIA_ALBA" => "1"),
  "vue_starter_alba" => starter("vue").merge("INERTIA_ALBA" => "1"),
  "svelte_starter_alba" => starter("svelte").merge("INERTIA_ALBA" => "1"),
  # ESLint + typelizer (JS, no TS — tests prettierrc-without-tailwind + typelizer ESLint exclusion)
  "react_eslint_typelizer" => foundation("react", INERTIA_ESLINT: 1, INERTIA_TYPELIZER: 1)
}.freeze

ROUNDS = [ROUND_1, ROUND_2, ROUND_3, ROUND_4, ROUND_5].freeze

# ─── Runner ─────────────────────────────────────────────────────────

class MatrixRunner
  BASE_PORT = 3100

  def initialize(configs:, concurrency: 4, keep: false, skip_http: false)
    @configs = configs
    @concurrency = concurrency
    @keep = keep
    @skip_http = skip_http
    @results = {}
    @compiled_template = File.join(Dir.tmpdir, "inertia_matrix_template.rb")
    @port_mutex = Mutex.new
    @next_port = BASE_PORT
  end

  def run
    compile_template
    FileUtils.mkdir_p(RESULTS_DIR)

    puts "╔══════════════════════════════════════════════════════════════╗"
    puts "║  Matrix Test — #{@configs.size} configs, #{@concurrency} workers#{" " * (25 - @configs.size.to_s.length - @concurrency.to_s.length)}║"
    puts "╚══════════════════════════════════════════════════════════════╝"
    puts

    work_dir = File.expand_path("../tmp/matrix_apps", __dir__)
    FileUtils.mkdir_p(work_dir)

    queue = @configs.to_a
    threads = []
    mutex = Mutex.new

    @concurrency.times do
      threads << Thread.new do
        loop do
          name, env = mutex.synchronize { queue.shift }
          break unless name

          result = run_one(name, env, work_dir)
          mutex.synchronize do
            @results[name] = result
            save_result(name, result)
            print_result(name, result)
          end
        end
      end
    end

    threads.each(&:join)
    print_summary
  end

  private

  def compile_template
    puts "Compiling template..."
    E2eHelpers.compile_template(@compiled_template)
    puts "Template compiled (#{(File.size(@compiled_template) / 1024.0).round(1)} KB)"
    puts
  end

  def run_one(name, env, work_dir)
    result = {
      name: name,
      env: env,
      steps: {},
      files: [],
      started_at: Time.now
    }

    app_name = "app_#{name}"
    app_path = File.join(work_dir, app_name)

    # Clean previous run
    FileUtils.rm_rf(app_path)

    is_starter = env["INERTIA_STARTER_KIT"] == "1"

    cmd = ["rails", "new", app_name, "-m", @compiled_template, *RAILS_FLAGS]
    cmd.push(*FOUNDATION_FLAGS) unless is_starter

    template_env = COMMON_ENV.merge(env)

    # Step 1: rails new
    stdout, stderr, status = Bundler.with_original_env do
      Open3.capture3(template_env, *cmd, chdir: work_dir)
    end
    output = "#{stdout}\n#{stderr}"
    result[:steps][:rails_new] = status.success? ? :pass : :FAIL
    result[:rails_new_output] = output unless status.success?

    unless status.success?
      result[:finished_at] = Time.now
      return result
    end

    # Capture file tree
    result[:files] = Dir.glob("#{app_path}/**/*", File::FNM_DOTMATCH)
      .select { |f| File.file?(f) }
      .map { |f| f.sub("#{app_path}/", "") }
      .sort
    result[:file_count] = result[:files].size

    # Capture key deps
    pkg_path = File.join(app_path, "package.json")
    if File.exist?(pkg_path)
      pkg = JSON.parse(File.read(pkg_path))
      result[:npm_deps] = (pkg["dependencies"] || {}).keys.sort
      result[:npm_dev_deps] = (pkg["devDependencies"] || {}).keys.sort
      result[:npm_scripts] = (pkg["scripts"] || {}).keys.sort
    end

    gemfile_path = File.join(app_path, "Gemfile")
    if File.exist?(gemfile_path)
      result[:gems] = File.read(gemfile_path).scan(/gem\s+["']([^"']+)["']/).flatten.sort
    end

    # Step 2: rails boot
    out, err, st = run_in_app(app_path, "bin/rails runner 'puts :ok'")
    result[:steps][:rails_boot] = st.success? ? :pass : :FAIL
    result[:rails_boot_output] = "#{out}\n#{err}" unless st.success?

    if st.success?
      # Step 3: vite build
      out, err, st = run_in_app(app_path, "npx vite build")
      result[:steps][:vite_build] = st.success? ? :pass : :FAIL
      result[:vite_build_output] = "#{out}\n#{err}" unless st.success?

      # Step 4: vite SSR build (if applicable)
      if is_starter || env["INERTIA_SSR"] == "1"
        out, err, st = run_in_app(app_path, "npx vite build --ssr")
        result[:steps][:vite_ssr] = st.success? ? :pass : :FAIL
        result[:vite_ssr_output] = "#{out}\n#{err}" unless st.success?
      else
        result[:steps][:vite_ssr] = :skip
      end

      # Step 5: npm scripts
      scripts = result[:npm_scripts] || []

      if scripts.include?("check")
        out, err, st = run_in_app(app_path, "npm run check")
        result[:steps][:npm_check] = st.success? ? :pass : :FAIL
        result[:npm_check_output] = "#{out}\n#{err}" unless st.success?
      else
        result[:steps][:npm_check] = :skip
      end

      if scripts.include?("lint")
        out, err, st = run_in_app(app_path, "npm run lint")
        result[:steps][:npm_lint] = st.success? ? :pass : :FAIL
        result[:npm_lint_output] = "#{out}\n#{err}" unless st.success?
      else
        result[:steps][:npm_lint] = :skip
      end

      # Step 6: HTTP smoke tests
      if @skip_http
        result[:steps][:http_smoke] = :skip
      else
        errors = run_http_smoke(app_path, is_starter)
        result[:steps][:http_smoke] = errors.empty? ? :pass : :FAIL
        result[:http_smoke_output] = errors.join("\n") unless errors.empty?
      end
    end

    # Clean up unless --keep
    FileUtils.rm_rf(app_path) unless @keep

    result[:finished_at] = Time.now
    result
  end

  def run_in_app(app_path, cmd)
    Bundler.with_original_env do
      Open3.capture3(cmd, chdir: app_path)
    end
  end

  def allocate_port
    @port_mutex.synchronize { @next_port += 1 }
  end

  def run_http_smoke(app_path, is_starter)
    errors = []
    port = allocate_port

    # Start Rails server
    server_pid = nil
    server_log = File.join(app_path, "tmp/smoke_server.log")

    begin
      server_pid = Bundler.with_original_env do
        Process.spawn(
          {"RAILS_ENV" => "development", "RAILS_LOG_TO_STDOUT" => "0"},
          "bin/rails", "server", "-p", port.to_s, "-b", "127.0.0.1",
          chdir: app_path,
          out: server_log, err: server_log
        )
      end

      # Wait for server to be ready
      ready = false
      20.times do
        sleep 0.5
        begin
          Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/up"))
          ready = true
          break
        rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
          # not ready yet
        end
      end

      unless ready
        log = File.exist?(server_log) ? File.read(server_log).lines.last(20).join : "(no log)"
        errors << "Server failed to start on port #{port}:\n#{log}"
        return errors
      end

      # Test 1: GET / → HTML with Inertia page
      resp = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/"))
      if resp.code != "200"
        errors << "GET / returned #{resp.code} (expected 200)"
      else
        body = resp.body
        unless body.include?("id=\"app\"") || body.include?("data-page")
          errors << "GET / missing Inertia mount point (no id=\"app\" or data-page)"
        end
        unless body.include?("vite")
          errors << "GET / missing vite tags in HTML"
        end
      end

      # Test 2: GET / with X-Inertia header → JSON
      uri = URI("http://127.0.0.1:#{port}/")
      req = Net::HTTP::Get.new(uri)
      req["X-Inertia"] = "true"
      req["X-Inertia-Version"] = ""
      req["Accept"] = "application/json"
      resp = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

      if resp.code == "200"
        begin
          json = JSON.parse(resp.body)
          errors << "Inertia JSON missing 'component'" unless json.key?("component")
          errors << "Inertia JSON missing 'props'" unless json.key?("props")
          errors << "Inertia JSON missing 'url'" unless json.key?("url")
        rescue JSON::ParserError
          errors << "Inertia response is not valid JSON: #{resp.body[0..200]}"
        end
      elsif resp.code == "409"
        # Version mismatch — means Inertia is working but asset version differs, that's OK
      else
        errors << "GET / (Inertia XHR) returned #{resp.code} (expected 200 or 409)"
      end

      if is_starter
        # Test 3: GET /sign_in → 200 (login page)
        resp = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/sign_in"))
        if resp.code != "200"
          errors << "GET /sign_in returned #{resp.code} (expected 200)"
        end

        # Test 4: GET /dashboard → redirect to sign_in (unauthenticated)
        resp = Net::HTTP.get_response(URI("http://127.0.0.1:#{port}/dashboard"))
        unless %w[302 303].include?(resp.code)
          errors << "GET /dashboard returned #{resp.code} (expected 302/303 redirect)"
        end
      end
    ensure
      if server_pid
        begin
          Process.kill("TERM", server_pid)
        rescue
          nil
        end
        begin
          Process.wait(server_pid)
        rescue
          nil
        end
      end
    end

    errors
  end

  def save_result(name, result)
    path = File.join(RESULTS_DIR, "#{name}.txt")
    File.open(path, "w") do |f|
      f.puts "Config: #{name}"
      f.puts "Env: #{result[:env].inspect}"
      f.puts "Files: #{result[:file_count] || "N/A"}"
      f.puts "Duration: #{duration(result)}s"
      f.puts
      f.puts "Steps:"
      result[:steps].each { |step, status| f.puts "  #{step}: #{status}" }

      # Dump failure output
      result.each do |key, val|
        next unless key.to_s.end_with?("_output")
        f.puts
        f.puts "─── #{key} ───"
        lines = val.to_s.lines
        f.puts lines.last(100).join
      end

      # File tree
      if result[:files]&.any?
        f.puts
        f.puts "─── file tree (#{result[:file_count]} files) ───"
        result[:files].each { |file| f.puts "  #{file}" }
      end
    end
  end

  def print_result(name, result)
    status_str = result[:steps].map do |step, status|
      icon = case status
      when :pass then "\e[32m✓\e[0m"
      when :FAIL then "\e[31m✗\e[0m"
      when :skip then "\e[33m-\e[0m"
      end
      "#{step}:#{icon}"
    end.join(" ")

    files = result[:file_count] ? "#{result[:file_count]} files" : "—"
    dur = duration(result)

    failed = result[:steps].any? { |_, s| s == :FAIL }
    name_color = failed ? "\e[31m" : "\e[32m"

    puts "  #{name_color}%-30s\e[0m %s  [%s, %ss]" % [name, status_str, files, dur]
  end

  def print_summary
    puts
    puts "═" * 66

    passed = @results.count { |_, r| r[:steps].values.none? { |s| s == :FAIL } }
    failed = @results.size - passed
    total_time = @results.values.sum { |r| duration(r).to_f }.round(0)

    if failed == 0
      puts "\e[32m  ALL #{passed} CONFIGS PASSED\e[0m (#{total_time}s total work, wall time less with parallelism)"
    else
      puts "\e[31m  #{failed} FAILED\e[0m, #{passed} passed"
      puts
      puts "  Failed configs:"
      @results.each do |name, result|
        fails = result[:steps].select { |_, s| s == :FAIL }
        next if fails.empty?
        puts "    \e[31m#{name}\e[0m — failed at: #{fails.keys.join(", ")}"
        puts "    Result saved: #{RESULTS_DIR}/#{name}.txt"
      end
    end

    puts "═" * 66
    puts
    puts "Results saved in: #{RESULTS_DIR}/"
    puts "Re-run failures: ruby test/matrix_test.rb --only #{@results.select { |_, r| r[:steps].any? { |_, s| s == :FAIL } }.keys.join(",")}" if failed > 0
  end

  def duration(result)
    return "?" unless result[:started_at] && result[:finished_at]
    (result[:finished_at] - result[:started_at]).round(1)
  end
end

# ─── CLI ────────────────────────────────────────────────────────────

options = {round: 1, concurrency: 4, keep: false, only: nil, skip_http: false}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby test/matrix_test.rb [options]"

  opts.on("--round N", Integer, "Run rounds 1..N (default: 1)") { |n| options[:round] = n }
  opts.on("--only NAMES", "Run only these configs (comma-separated)") { |s| options[:only] = s.split(",") }
  opts.on("--concurrency N", Integer, "Parallel workers (default: 4)") { |n| options[:concurrency] = n }
  opts.on("--keep", "Keep generated apps in tmp/matrix_apps/") { options[:keep] = true }
  opts.on("--skip-http", "Skip HTTP smoke tests") { options[:skip_http] = true }
end.parse!

# Build config set
if options[:only]
  all_configs = ROUNDS.reduce({}, :merge)
  configs = options[:only].each_with_object({}) do |name, h|
    if all_configs.key?(name)
      h[name] = all_configs[name]
    else
      warn "Unknown config: #{name} (available: #{all_configs.keys.join(", ")})"
      exit 1
    end
  end
else
  configs = {}
  options[:round].times { |i| configs.merge!(ROUNDS[i]) }
end

MatrixRunner.new(configs: configs, concurrency: options[:concurrency], keep: options[:keep], skip_http: options[:skip_http]).run
