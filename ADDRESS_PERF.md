# Performance Issues to Address

## Status Tracking
- [x] 1. CRITICAL: `find_trak_at` O(n) memory load ✅ (O(n) → O(1) memory)
- [ ] 2. HIGH: N+1 queries on `item`/`whodunnit` (documentation fix)
- [x] 3. HIGH: Callbacks run inside transaction ✅ (callback_type: :after_commit option)
- [x] 4. MEDIUM: Single-pass changeset filter ✅ (13% faster, no-filters path)
- [x] 5. MEDIUM: Pre-convert filter symbols to strings ✅ (8-20% improvement)
- [x] 6. MEDIUM: Cache ignored_attrs as Set — SKIPPED ❌ (benchmark shows Set is slower for small arrays)
- [x] 7. LOW: Reduce respond_to? checks ✅ (22% faster on Context calls)

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

### 4. Remove unnecessary hash dup and merge ignore filters

**Files changed:**
- `lib/trakable/tracker.rb` - Remove `changes.dup`, combine record + global ignore into single `except` call

**Results (200k iterations, median of 5 runs):**
- filter_changeset (with only/ignore): 0.637µs → 0.643µs (~0%, within noise)
- filter_changeset (without model filters): 0.367µs → 0.318µs (13% faster)

**Note:** True single-pass with `select/reject` blocks was benchmarked but proved slower than C-optimized `Hash#slice`/`Hash#except`. The win comes from removing the redundant `.dup` and merging two `except` calls.

---

### 7. Remove redundant respond_to? checks on Context

**Files changed:**
- `lib/trakable/tracker.rb` - Remove `Context.respond_to?` guards on `whodunnit`, `metadata`, `tracking_enabled?`

**Results (500k iterations, median of 5 runs):**
- 3x Context access (respond_to? + call): 0.320µs → 0.250µs (22% faster)

---

### 1. find_trak_at DB query instead of in-memory filter

**Files changed:**
- `lib/trakable/revertable.rb` - Use `WHERE + ORDER + LIMIT 1` when traks is an ActiveRecord relation

**Results:**
- Before: loads ALL traks into memory, filters in Ruby → O(n) memory
- After: single indexed DB query → O(1) memory
- Duck-type check overhead (`respond_to?(:where)`): negligible (~0.02µs)
- Fallback to in-memory filter for arrays (test compatibility)

---

### 3. after_commit callback option

**Files changed:**
- `lib/trakable/model.rb` - Add `callback_type: :after_commit` option
- `test/trakable/model_test.rb` - Tests for after_commit callbacks

**Results:**
- No perf benchmark (semantic change, not speed optimization)
- Tracking occurs after transaction commits, preventing trak writes if transaction rolls back

---

### 6. Cache ignored_attrs as Set — SKIPPED

**Benchmark showed Set#include? is slower than Array#include? for small collections:**
- Array#include?: 22.22ms (50k iterations)
- Set#include?: 23.92ms (50k iterations)
- Speedup: 0.93x (Set is 7% slower)

Ruby's Set has object allocation overhead that outweighs O(1) lookup benefit for arrays under ~20 elements. Since ignored_attrs typically has 3-5 entries, Array is faster.

---

## Remaining

### 2. HIGH: N+1 Queries on `item`/`whodunnit`

**File:** `lib/trakable/trak.rb:62-76`

**Problem:** Each `trak.item` or `trak.whodunnit` triggers a separate query.

**Fix:** Document eager loading pattern in README:
```ruby
# Eager load to avoid N+1
record.traks.includes(:item)
```
