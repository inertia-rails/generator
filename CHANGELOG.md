# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- Initial implementation
- Emit `.node-version` as the single source for CI workflows (`node-version-file`) and the Dockerfile `NODE_VERSION` arg, instead of a hardcoded Node 22 in workflows
- `bin/ci` freshness check for Typelizer-generated routes and serializer types
- README note on the `typescript@~6.0` pin (typescript-eslint peer range caps at `<6.1`)
- Server-managed meta tags out of the box: `config.server_head`, `serverHead: true` in every entrypoint, and `inertia_meta_tags(default_title: ...)` in the layout instead of a plain `<title>` (requires inertia_rails 3.23 and Inertia.js 3.5)
- `config.convert_fragment_redirects = true` in the generated initializer
- Generated workflows limit the `GITHUB_TOKEN` to `contents: read` and check out with `persist-credentials: false`
- 5-day Dependabot cooldown on the JS ecosystem entry
- Starter kit rate-limits sign-in, sign-up, password reset, and password update (10 attempts per 3 minutes per IP)
- Stamp the compiled template with the commit SHA it was built from and print it at startup, so bug reports can name the build

### Fixed

- `.prettierignore` now covers all generated dirs (shadcn `components/ui`, alba `types/serializers`), matching the ESLint ignores
- `bin/ci` keeps Rails test and seed steps on the Foundation path (previously dropped when replacing the stock `config/ci.rb`)
- Apps with an existing `vite.config` now get the `inertia()` plugin, and plugins are appended after the existing ones in order (previously prepended in reverse, with `inertia()` missing)
- An existing `vite.config` that already sets up the framework plugin (including with options, e.g. `react({ ... })`) no longer gets a second copy or a duplicate import, and `reactCompilerPreset` is imported for the added `babel()` plugin
- `bin/ci` runs lint, format, type check, and audit through the app's package manager instead of always `npm`
- Dependabot uses the `bun` ecosystem for Bun apps instead of `npm`
- Existing apps: the installer's own `bundle install` failed on the gems it had just added, because it inherited the bundle of the running `bin/rails app:template`. Rails installed them afterwards, but the boot check, binstubs and `typelizer:generate` ran too early. These commands now run with the original environment
