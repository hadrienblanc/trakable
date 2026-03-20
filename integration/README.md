# Trakable Integration Tests

## Overview

Integration tests simulate real-world usage scenarios of the Trakable gem. Each scenario tests a complete feature or workflow from start to finish.

## Running Tests

```bash
# Run all integration scenarios
ruby integration/run_all.rb

# Run a specific scenario
ruby integration/scenarios/01-basic-tracking/scenario.rb
```

## Scenarios

| # | Scenario | Description |
|---|----------|-------------|
| 01 | Basic Tracking | Tests create/update/destroy tracking |
| 02 | Revert & Restoration | Tests revert! and reify functionality |
| 03 | Whodunnit Tracking | Tests polymorphic whodunnit and context |
| 04 | Cleanup & Retention | Tests max_traks and retention policies |
| 05 | Without Tracking | Tests skipping tracking |

## Creating a New Scenario

1. Create a new directory: `integration/scenarios/NN-description/`
2. Create `scenario.rb` with your test code
3. Include the scenario runner:

```ruby
# frozen_string_literal: true

require_relative '../scenario_runner'

run_scenario 'My Scenario Name' do
  puts '=== Scenario NN: My Scenario Name ==='

  # Your test code here

  puts '=== Scenario NN PASSED ✓ ==='
end
```

## Scenario Structure

Each scenario should:
- Be self-contained and runnable independently
- Clean up after itself (reset context, etc.)
- Print clear progress messages
- Use assertions to verify behavior
- Handle exceptions gracefully

## Available Assertions

```ruby
assert(condition, message)
assert_equal(expected, actual)
assert_kind_of(Class, object)
assert_includes(collection, item)
refute(condition, message)
refute_nil(object)
```
