# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-20

### Added

- **Query scopes** on `Trakable::Trak` (AR-only): `for_item_type`, `for_event`, `for_whodunnit`, `created_before`, `created_after`, `recent`
- **Batch deletion** in `run_retention` with configurable `batch_size` (default: 1,000) to avoid table locks
- **CI/CD** via GitHub Actions (Ruby 3.1–3.4 matrix, tests + RuboCop)

### Changed

- **Cleanup is no longer synchronous** — `Cleanup.run` is no longer called after every trak creation. Run it from a background job instead.
- `run_retention` now returns the total number of deleted rows (Integer) instead of `true`

## [0.1.0] - 2026-03-20

### Added

- Initial release of Trakable gem
- **Trak model** with JSON serialization for object, changeset, and metadata
- **Polymorphic whodunnit** tracking (type + id) instead of string
- **Trakable DSL** for ActiveRecord models with options:
  - `only:` - track specific attributes
  - `ignore:` - skip specific attributes
  - `if:` / `unless:` - conditional tracking
  - `on:` - selective events (create, update, destroy)
- **Revertable module**:
  - `reify` - build non-persisted record from Trak state
  - `revert!` - restore record to previous state
  - `trak_at` - get record state at specific timestamp
- **Controller concern** with automatic whodunnit setting via `around_action`
- **Cleanup module** with:
  - `max_traks` - limit number of traks per record
  - `retention` - automatic pruning of old traks
- **Railtie** for Rails integration with:
  - Configuration auto-loading from `config.trakable`
  - Install generator for migration and initializer
- **Thread-safe context** for storing whodunnit and metadata
- **Global configuration** via `Trakable.configure`
- Comprehensive README with usage examples
- MIT License

[0.2.0]: https://github.com/hadrienblanc/trakable/releases/tag/v0.2.0
[0.1.0]: https://github.com/hadrienblanc/trakable/releases/tag/v0.1.0
