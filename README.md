# Trakable

Audit logging and version tracking for ActiveRecord models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'trakable'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install trakable
```

## Quick Start

### 1. Generate the migration

```bash
$ rails generate trakable:install
```

This creates:
- `db/migrate/create_traks.rb` - Migration for the traks table
- `config/initializers/trakable.rb` - Configuration file

Run the migration:

```bash
$ rails db:migrate
```

### 2. Add tracking to your models

```ruby
class Post < ApplicationRecord
  include Trakable::Model

  trakable only: %i[title body], ignore: %i[views_count]
end
```

### 3. Whodunnit is automatic

Trakable auto-includes its controller concern via Railtie. It calls `current_user` by default — no setup needed.

To use a different method:

```ruby
Trakable.configure do |config|
  config.whodunnit_method = :current_admin
end
```

## Configuration

### Global configuration

In `config/initializers/trakable.rb`:

```ruby
Trakable.configure do |config|
  # Enable/disable tracking globally
  config.enabled = true

  # Attributes to ignore by default
  config.ignored_attrs = %w[created_at updated_at id]

  # Controller method that returns the current user (default: :current_user)
  config.whodunnit_method = :current_user
end
```

### Per-model options

```ruby
class Post < ApplicationRecord
  include Trakable::Model

  trakable(
    only: %i[title body],      # Only track these attributes
    ignore: %i[views_count],   # Ignore these attributes
    on: %i[create update destroy],  # Only track these events (default: all)
    if: -> { published? },     # Conditional tracking
    unless: -> { draft? }      # Skip if true
  )
end
```

## Usage

### Accessing traks

```ruby
post = Post.first

# Get all traks for a record
post.traks

# Get the last trak
post.traks.last
```

### Trak properties

```ruby
trak = post.traks.last

trak.event       # => "update"
trak.create?     # => false
trak.update?     # => true
trak.destroy?    # => false

trak.changeset   # => { "title" => ["Old Title", "New Title"] }
trak.object      # => { "title" => "Old Title", "body" => "..." }
trak.metadata    # => { "ip" => "192.168.1.1", "user_agent" => "..." }
trak.created_at  # => 2024-01-15 10:30:00 UTC

# Whodunnit (polymorphic)
trak.whodunnit_type  # => "User"
trak.whodunnit_id    # => 42
trak.whodunnit       # => #<User id: 42, ...>
```

### Setting metadata

You can add custom metadata to traks using the context:

```ruby
Trakable::Context.metadata = { ip: request.ip, user_agent: request.user_agent }
post.update(title: "New Title")
# The created trak will include the metadata
```

### Revert changes

```ruby
# Restore the record to the state before this trak
post.traks.last.revert!

# Revert and create a trak for the revert action
post.traks.last.revert!(trak_revert: true)
```

### Time travel

```ruby
# Get the state at a specific point in time
post.trak_at(1.day.ago)  # => Non-persisted record with state from 1 day ago

# Get the state from a specific trak
post.traks.last.reify  # => Non-persisted record with state at that trak
```

### Query scopes

```ruby
# Filter by model type
Trakable::Trak.for_item_type('Post')

# Filter by event
Trakable::Trak.for_event(:update)

# Filter by whodunnit
Trakable::Trak.for_whodunnit(current_user)

# Filter by time range
Trakable::Trak.created_after(1.week.ago)
Trakable::Trak.created_before(Date.yesterday)

# Newest first
Trakable::Trak.recent

# Combine them
Trakable::Trak.for_item_type('Post').for_event(:update).created_after(1.day.ago).recent
```

### Temporarily disable tracking

```ruby
# Disable tracking for a block
Trakable.without_tracking do
  post.update(title: "Won't be tracked")
end

# Force tracking when globally disabled
Trakable.with_tracking do
  post.update(title: "Will be tracked")
end

# Set whodunnit manually
Trakable.with_user(current_user) do
  post.update(title: "Tracked with user")
end
```

### Cleanup

Configure cleanup options per model:

```ruby
class Post < ApplicationRecord
  include Trakable::Model

  trakable max_traks: 100      # Keep only last 100 traks
  trakable retention: 90.days  # Delete traks older than 90 days
end
```

Cleanup is **not** automatic — call it from a background job to keep your traks table lean:

```ruby
# In a recurring job (e.g. daily cron)
Trakable::Cleanup.run_retention(Post)

# Per-record cleanup (e.g. after a batch import)
Trakable::Cleanup.run(post)
```

### Edge cases

```ruby
# When no trak exists at the timestamp, returns current state
post.trak_at(1.year.ago)  # => Returns current state if no older traks exist

# When whodunnit record is deleted, returns nil
trak.whodunnit  # => nil (if the user was deleted)

# Revert on destroy re-creates the record (with new ID)
destroy_trak = post.traks.where(event: 'destroy').last
destroy_trak.revert!  # => Creates new record with same attributes but new ID
```

## API Reference

### Trakable::Model

| Method | Description |
|--------|-------------|
| `trakable(options)` | Configure tracking for this model |
| `traks` | Association to all traks for this record |
| `trak_at(timestamp)` | Get record state at a specific time |

### Trakable::Trak

| Method | Description |
|--------|-------------|
| `item` | The tracked record (polymorphic) |
| `whodunnit` | The user who made the change (polymorphic) |
| `event` | The event type: "create", "update", or "destroy" |
| `changeset` | Hash of changed attributes with [old, new] values |
| `object` | Changed attributes before the change (delta for updates, full snapshot for destroys) |
| `create?` | True if this is a create event |
| `update?` | True if this is an update event |
| `destroy?` | True if this is a destroy event |
| `reify` | Build non-persisted record with state at this trak |
| `revert!` | Restore record to state before this trak |
| `for_item_type(type)` | Scope: filter by item type |
| `for_event(event)` | Scope: filter by event |
| `for_whodunnit(user)` | Scope: filter by whodunnit (polymorphic) |
| `created_before(time)` | Scope: traks before a timestamp |
| `created_after(time)` | Scope: traks after a timestamp |
| `recent` | Scope: newest first |

### Trakable::Controller (auto-included via Railtie)

| Option | Description |
|--------|-------------|
| `config.whodunnit_method` | Controller method that returns the current user (default: `:current_user`) |

## Performance Tips

### Eager loading (N+1 prevention)

When loading multiple records with their traks, use `includes` to avoid N+1 queries:

```ruby
# Bad — N+1
posts = Post.all
posts.each { |p| p.traks.count }

# Good — eager loaded
posts = Post.includes(:traks).all
posts.each { |p| p.traks.size }
```

### Compress serialized columns (Rails 7.1+)

For large `object`/`changeset` payloads, enable column compression by adding a custom initializer:

```ruby
# config/initializers/trakable_compression.rb
Rails.application.config.after_initialize do
  Trakable::Trak.serialize :object, coder: JSON, compress: true
  Trakable::Trak.serialize :changeset, coder: JSON, compress: true
end
```

This uses zlib under the hood and can reduce storage by 60-80% for large payloads.

## Differences from PaperTrail

| Feature | PaperTrail | Trakable |
|---------|------------|----------|
| Whodunnit | String | Polymorphic (type + id) |
| Changeset | Opt-in | Always stored |
| Metadata | Not native | Built-in column |
| Retention | Manual | Built-in (max_traks, retention) |
| Serialization | YAML default | JSON only |
| Table name | versions | traks |
| Updated_at | Yes | No (immutable) |

## Ruby Compatibility

171 tests, 331 assertions, 0 failures, 0 errors on all versions.

| Metric | 3.2.10 | 3.3.5 | 3.3.10 | 3.4.9 | 4.0.1 | 4.0.2 |
|---|---|---|---|---|---|---|
| **allocs_create** | 8 | 9 | 9 | 9 | 8 | 8 |
| **allocs_update** | 9 | 10 | 10 | 10 | 9 | 9 |
| **allocs_destroy** | 8 | 9 | 9 | 9 | 8 | 8 |
| **boot_time_us** | 40,890 | 56,041 | 49,047 | 56,931 | 56,901 | 58,085 |
| **speed_create_us** | 2.94 | 3.25 | 3.27 | 3.83 | 3.26 | 3.09 |
| **speed_update_us** | 3.20 | 3.67 | 3.32 | 4.08 | 3.42 | 3.39 |
| **speed_destroy_us** | 2.48 | 2.55 | 2.24 | 3.00 | 2.30 | 2.05 |
| **storage_wide_object_bytes** | 35 | 35 | 35 | 35 | 35 | 35 |
| **integration_total_allocs** | 253,024 | 243,592 | 234,909 | 138,966 | 135,954 | 133,413 |

`integration_total_allocs` includes system overhead (SimpleCov, ActiveSupport, Minitest). The variance across Ruby versions reflects internal runtime optimizations, not Trakable code. Actual scenario code accounts for ~55k allocs across all 37 scenarios.

The gem is lean:

- **9-10 allocs** per operation (the incompressible minimum to create a Trak + its hashes)
- **2-3us** per tracking call
- **35 bytes** of storage for an update on a 20-column model (delta)
- **0 unnecessary runtime dependency** (`require 'json'` removed, Controller autoloaded)
- **Thread-safe** configuration and controller

## License

The gem is available as open source under the terms of the [MIT License](./LICENSE).
