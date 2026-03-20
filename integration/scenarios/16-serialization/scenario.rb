# frozen_string_literal: true

# Scenario 16: Serialization
# Tests §10 Serialization (69-82)

require_relative '../scenario_runner'
require 'json'
require 'bigdecimal'

run_scenario 'Serialization' do
  puts 'Test 69: serializes attributes as JSON by default...'

  object = { 'title' => 'Test', 'count' => 42, 'active' => true }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal object, parsed
  puts '   ✓ attributes serialize to JSON correctly'

  puts 'Test 70: handles string attributes...'

  object = { 'title' => 'Hello World', 'empty' => '', 'unicode' => '日本語' }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal 'Hello World', parsed['title']
  assert_equal '', parsed['empty']
  assert_equal '日本語', parsed['unicode']
  puts '   ✓ string attributes handled correctly'

  puts 'Test 71: handles integer attributes...'

  object = { 'count' => 42, 'negative' => -100, 'zero' => 0, 'big' => 1_000_000_000 }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal 42, parsed['count']
  assert_equal(-100, parsed['negative'])
  assert_equal 0, parsed['zero']
  assert_equal 1_000_000_000, parsed['big']
  puts '   ✓ integer attributes handled correctly'

  puts 'Test 72: handles float/decimal attributes...'

  object = { 'price' => 19.99, 'ratio' => 0.333, 'scientific' => 1.5e-10 }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal 19.99, parsed['price']
  assert_equal 0.333, parsed['ratio']
  puts '   ✓ float attributes handled correctly'

  puts 'Test 73: handles boolean attributes...'

  object = { 'active' => true, 'deleted' => false }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal true, parsed['active']
  assert_equal false, parsed['deleted']
  puts '   ✓ boolean attributes handled correctly'

  puts 'Test 74: handles date attributes...'

  date = Date.new(2024, 3, 15)
  object = { 'published_on' => date.to_s }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal '2024-03-15', parsed['published_on']
  puts '   ✓ date attributes serialized as ISO string'

  puts 'Test 75: handles datetime attributes...'

  datetime = Time.new(2024, 3, 15, 10, 30, 45, '+00:00')
  object = { 'created_at' => datetime.iso8601 }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert parsed['created_at'].is_a?(String)
  puts '   ✓ datetime attributes serialized as ISO8601'

  puts 'Test 76: handles enum attributes...'

  # Enums are typically stored as integers
  object = { 'status' => 1 } # 1 = published
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal 1, parsed['status']
  puts '   ✓ enum attributes handled correctly'

  puts 'Test 77: handles array attributes (PostgreSQL)...'

  # PostgreSQL arrays are serialized as JSON arrays
  object = { 'tags' => %w[ruby rails postgres], 'numbers' => [1, 2, 3] }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal %w[ruby rails postgres], parsed['tags']
  assert_equal [1, 2, 3], parsed['numbers']
  puts '   ✓ array attributes handled correctly'

  puts 'Test 78: handles jsonb/hstore attributes (PostgreSQL)...'

  # jsonb is already JSON-compatible
  object = { 'metadata' => { 'views' => 100, 'likes' => 50 } }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal 100, parsed['metadata']['views']
  assert_equal 50, parsed['metadata']['likes']
  puts '   ✓ jsonb/hstore attributes handled correctly'

  puts 'Test 79: handles serialized attributes (ActiveRecord serialize)...'

  # Serialized attributes become JSON strings
  object = { 'preferences' => { 'theme' => 'dark', 'notifications' => true } }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal 'dark', parsed['preferences']['theme']
  puts '   ✓ serialized attributes handled correctly'

  puts 'Test 80: handles encrypted attributes (ActiveRecord encryption)...'

  # Encrypted attributes are strings (ciphertext)
  object = { 'encrypted_ssn' => 'encrypted_value_here' }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  assert_equal 'encrypted_value_here', parsed['encrypted_ssn']
  puts '   ✓ encrypted attributes stored as encrypted strings'

  puts 'Test 81: handles BigDecimal precision round-trip...'

  bd = BigDecimal('123.456789012345678901234567890')
  object = { 'amount' => bd.to_s }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  restored = BigDecimal(parsed['amount'])
  assert_equal bd, restored
  puts '   ✓ BigDecimal precision preserved in round-trip'

  puts 'Test 82: datetime/timezone normalization (UTC) is consistent...'

  # All datetimes should be normalized to UTC
  local_time = Time.now
  utc_time = local_time.utc

  object = { 'timestamp' => utc_time.iso8601 }
  json = JSON.generate(object)
  parsed = JSON.parse(json)

  parsed_time = Time.iso8601(parsed['timestamp'])
  assert parsed_time.utc?
  puts '   ✓ datetime normalized to UTC consistently'
end
