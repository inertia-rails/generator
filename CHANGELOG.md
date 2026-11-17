# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- Initial implementation
- Emit `.node-version` as the single source for CI workflows (`node-version-file`) and the Dockerfile `NODE_VERSION` arg, instead of a hardcoded Node 22 in workflows
- `bin/ci` freshness check for Typelizer-generated routes and serializer types
- README note on the `typescript@~6.0` pin (typescript-eslint peer range caps at `<6.1`)
- Generated workflows limit the `GITHUB_TOKEN` to `contents: read` and check out with `persist-credentials: false`
- 5-day Dependabot cooldown on the JS ecosystem entry

### Fixed

- `.prettierignore` now covers all generated dirs (shadcn `components/ui`, alba `types/serializers`), matching the ESLint ignores
- `bin/ci` keeps Rails test and seed steps on the Foundation path (previously dropped when replacing the stock `config/ci.rb`)
- `bin/ci` runs lint, format, type check, and audit through the app's package manager instead of always `npm`
- Dependabot uses the `bun` ecosystem for Bun apps instead of `npm`
