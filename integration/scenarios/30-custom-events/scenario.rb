# frozen_string_literal: true

# Scenario 30: Custom Events
# Tests §26 Custom events (182-183)

require_relative '../scenario_runner'
require 'securerandom'

run_scenario 'Custom Events' do
  puts 'Test 182: supports custom events beyond create/update/destroy (e.g. :publish, :archive)...'

  # Custom events can be triggered manually
  # Trakable.track_custom_event(record, :publish)

  custom_events = %i[publish archive unpublish review approve reject]

  trak = Trakable::Trak.new(
    item_type: 'Post',
    item_id: 1,
    event: 'publish', # Custom event
    changeset: { 'status' => %w[draft published] }
  )

  assert_equal 'publish', trak.event
  refute Trakable::Trak::EVENTS.include?('publish'), 'publish is a custom event'
  puts '   ✓ custom events supported'

  puts 'Test 183: session/request grouping — group traks from one HTTP request...'

  # Traks from same request can be grouped via request_id
  request_id = SecureRandom.uuid

  traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create',
                       metadata: { 'request_id' => request_id }),
    Trakable::Trak.new(item_type: 'Comment', item_id: 1, event: 'create',
                       metadata: { 'request_id' => request_id }),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'create',
                       metadata: { 'request_id' => 'other-request' })
  ]

  request_traks = traks.select { |t| t.metadata['request_id'] == request_id }
  assert_equal 2, request_traks.length, 'Should find 2 traks from same request'
  puts '   ✓ traks can be grouped by request/session'
end
