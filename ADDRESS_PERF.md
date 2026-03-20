# Performance Issues to Address

## Status Tracking
- [ ] 1. CRITICAL: `find_trak_at` O(n) memory load
- [ ] 2. HIGH: N+1 queries on `item`/`whodunnit`
- [ ] 3. HIGH: Callbacks run inside transaction
- [ ] 4. MEDIUM: Single-pass changeset filter
- [x] 5. MEDIUM: Pre-convert filter symbols to strings ✅ (8-20% improvement)
- [ ] 6. MEDIUM: Cache ignored_attrs as Set
- [ ] 7. LOW: Reduce respond_to? checks

## Completed Optimizations

### 5. Pre-convert filter symbols to strings

**Files changed:**
- `lib/trakable/model.rb` - Normalize `only`/`ignore` to strings in `trakable` method
- `lib/trakable/config.rb` - Ensure `ignored_attrs=` always converts to strings
- `lib/trakable/tracker.rb` - Defensive check for pre-converted strings

**Results:**
- filter_changeset (with filters): 1.46µs → 1.34µs (8% faster)
- filter_changeset (without filters): 0.74µs → 0.59µs (20% faster)

---

## 1. CRITICAL: `find_trak_at` O(n) Memory Load

**File:** `lib/trakable/revertable.rb:141`

**Current:**
```ruby
def find_trak_at(timestamp)
  traks.select { |t| t.created_at <= timestamp }.max_by(&:created_at)
end
```

**Problem:** Loads ALL traks into memory, then filters in Ruby. O(n) memory.

**Fix:**
```ruby
def find_trak_at(timestamp)
  traks.where('created_at <= ?', timestamp).order(created_at: :desc).first
end
```

**Note:** The gem's Trak class is a plain Ruby class for documentation. The fix applies to the host app's ActiveRecord Trak model.

---

## 2. HIGH: N+1 Queries on `item`/`whodunnit`

**File:** `lib/trakable/trak.rb:62-76`

**Problem:** Each `trak.item` or `trak.whodunnit` triggers a separate query.

**Fix:** Document eager loading pattern in README.

---

## 3. HIGH: Callbacks Run Inside Transaction

**File:** `lib/trakable/model.rb:48-60`

**Current:** Uses `after_create/update/destroy` (inside transaction)

**Fix:** Consider `after_commit on: [...]` option (configurable trade-off)

---

## 4. MEDIUM: Single-Pass Changeset Filter

**File:** `lib/trakable/tracker.rb:86-122`

**Current:** Multiple hash iterations (slice, except, except)

**Fix:**
```ruby
def filter_changeset(changes)
  return {} if changes.empty?

  only = record.trakable_options&.dig(:only)
  ignore = []
  ignore.concat(Array(record.trakable_options&.dig(:ignore))) if record.trakable_options&.dig(:ignore)
  ignore.concat(Array(Trakable.configuration.ignored_attrs)) if Trakable.configuration.ignored_attrs

  if only
    only_set = only.to_set
    ignore_set = ignore.to_set
    changes.select { |k, _| only_set.include?(k.to_s) && !ignore_set.include?(k.to_s) }
  elsif ignore.any?
    ignore_set = ignore.to_set
    changes.reject { |k, _| ignore_set.include?(k.to_s) }
  else
    changes
  end
end
```

---

## 5. MEDIUM: Pre-Convert Filter Symbols

**File:** `lib/trakable/tracker.rb:100,114,121`

**Current:** `Array(only).map(&:to_s)` called on every filter

**Fix:** Pre-convert at configuration time in `trakable` method.

---

## 6. MEDIUM: Cache ignored_attrs as Set

**File:** `lib/trakable/tracker.rb`

**Current:** `Array(ignored).map(&:to_s)` creates array, then `except` is O(n*m)

**Fix:** Use Set for O(1) lookups.

---

## 7. LOW: Reduce respond_to? Checks

**File:** `lib/trakable/tracker.rb:37,43,95,109,135,139`

**Current:** `respond_to?` on every callback invocation

**Fix:** Trust module structure or memoize at class level.
