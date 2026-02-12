# Inertia Rails Generator

[![Test](https://github.com/inertia-rails/generator/actions/workflows/test.yml/badge.svg)](https://github.com/inertia-rails/generator/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

> **Beta:** This generator will replace the built-in `rails generate inertia_rails:install`
> command in a future release of [inertia_rails](https://github.com/inertia-rails/inertia_rails).

Interactive Rails application template for setting up
[Inertia Rails](https://inertia-rails.dev) with React, Vue, or Svelte.

You can choose between two setup paths:

- **Foundation** — a modular setup where you pick features individually
  (TypeScript, Tailwind, shadcn, ESLint, SSR, and more).
- **Starter Kit** — a batteries-included app with authentication, dashboard,
  settings pages, dark mode, and sidebar/header layouts (similar to
  [Laravel Breeze](https://laravel.com/docs/starter-kits)).

## Usage

### New app

Create a new Rails app with Inertia pre-configured:

```sh
rails new myapp -m https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb
```

### Existing app

Run the generator against an existing Rails app. It auto-detects your
framework, TypeScript, Tailwind, Vite, and package manager:

```sh
rails app:template LOCATION=https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb
```

### Non-interactive mode

Set environment variables to skip prompts. This is useful for CI and scripting:

```sh
INERTIA_FRAMEWORK=react \
INERTIA_STARTER_KIT=1 \
rails new myapp -m https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb
```

## Setup paths

### Foundation

Pick individual features for your project. The following options are available:

| Option            | Env variable             | Values                          | Default     |
|-------------------|--------------------------|---------------------------------|-------------|
| Framework         | `INERTIA_FRAMEWORK`      | `react`, `vue`, `svelte`        | `react`     |
| TypeScript        | `INERTIA_TS`             | `1` / `0`                       | prompted    |
| Tailwind CSS v4   | `INERTIA_TAILWIND`       | `1` / `0`                       | prompted    |
| shadcn/ui         | `INERTIA_SHADCN`         | `1` / `0` (requires Tailwind + TS) | prompted |
| ESLint + Prettier | `INERTIA_ESLINT`         | `1` / `0`                       | prompted    |
| SSR               | `INERTIA_SSR`            | `1` / `0`                       | prompted    |
| Typelizer         | `INERTIA_TYPELIZER`      | `1` / `0`                       | prompted    |
| Alba serializers  | `INERTIA_ALBA`           | `1` / `0`                       | prompted    |
| Test framework    | `INERTIA_TEST_FRAMEWORK` | `minitest`, `rspec`             | `minitest`  |

Foundation generates a welcome page with a `HomeController` and a root route
to get you started.

### Starter Kit

The Starter Kit forces TypeScript, Tailwind, shadcn/ui, ESLint, SSR, and
Typelizer on, and adds full authentication:

```sh
INERTIA_FRAMEWORK=react INERTIA_STARTER_KIT=1 \
rails new myapp -m https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb
```

The Starter Kit includes:

- Authentication (register, login, forgot/reset password, email verification)
- Dashboard with sidebar and header layout variants
- Settings pages (profile, password, email, appearance, sessions)
- Dark mode with system/light/dark preferences
- Controller and mailer test suites (Minitest or RSpec)
- Alba + Typelizer for typed serializers (optional)

Pre-built starter kit apps are also available as standalone repos:

- [inertia-rails/react-starter-kit](https://github.com/inertia-rails/react-starter-kit)
- [inertia-rails/vue-starter-kit](https://github.com/inertia-rails/vue-starter-kit)
- [inertia-rails/svelte-starter-kit](https://github.com/inertia-rails/svelte-starter-kit)

## Features

Both setup paths share the following features:

- **Auto-detection** — detects existing Vite, framework, TypeScript, Tailwind,
  and package manager in existing apps
- **Package managers** — npm, yarn, pnpm, and bun
- **Conflict cleanup** — removes `importmap-rails`, `turbo-rails`, and
  `stimulus-rails` in fresh apps. Blocks if `jsbundling-rails` or
  `cssbundling-rails` are present (they conflict with Vite)
- **Vite Ruby** — configured with HMR, SSR support, and framework-specific
  plugins (`@vitejs/plugin-react`, `@vitejs/plugin-vue`, `@sveltejs/vite-plugin-svelte`)
- **shadcn/ui** — React
  ([shadcn](https://ui.shadcn.com)), Vue
  ([shadcn-vue](https://www.shadcn-vue.com)), Svelte
  ([shadcn-svelte](https://www.shadcn-svelte.com))
- **Dockerfile** — generates a production Dockerfile with Node.js, your
  package manager, and SSR support when `--docker` is used
- **CI workflow** — generates a GitHub Actions workflow with lint, type check,
  and test jobs. Adds a separate `lint_js` workflow for existing apps
- **Dependabot** — adds the `npm` ecosystem to your existing
  `.github/dependabot.yml`
- **`Procfile.dev` and `bin/dev`** — starts Vite dev server alongside Rails

## Tips

You can combine the generator with standard `rails new` flags:

```sh
# PostgreSQL + Docker
rails new myapp --database=postgresql --docker \
  -m https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb

# With devcontainer
rails new myapp --devcontainer -m https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb

# Skip default Rails extras
rails new myapp --skip-action-mailbox --skip-action-text \
  --skip-active-storage -m https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb
```

For existing apps, the Foundation path is recommended. If you need
authentication, add
[authentication-zero](https://github.com/lazaronixon/authentication-zero)
separately after running the generator.

## Development

Install dependencies and run the default task (compile, test, lint):

```sh
bundle install
bundle exec rake
```

Run the end-to-end tests. These are slow because each test runs `rails new`:

```sh
bundle exec rake test:e2e
```

Generate starter kit apps locally:

```sh
bundle exec rake starter:react   # tmp/react-starter-kit/
bundle exec rake starter:vue     # tmp/vue-starter-kit/
bundle exec rake starter:svelte  # tmp/svelte-starter-kit/
bundle exec rake starter:all     # all three
```

Run the detect + prompts phase without making changes (useful for debugging):

```sh
bundle exec rake detect              # against a fresh app
bundle exec rake detect APP=path/to  # against an existing app
```

Test a specific matrix of configurations:

```sh
ruby test/matrix_test.rb                  # Round 1: 6 configs
ruby test/matrix_test.rb --round 2        # Rounds 1-2: 15 configs
ruby test/matrix_test.rb --round 5        # All rounds: 27+ configs
ruby test/matrix_test.rb --only react_max # Re-run one config
```

## License

MIT
