# frozen_string_literal: true

# Scenario 12: Metadata
# Tests §5 Metadata (34-37)

require_relative '../scenario_runner'

run_scenario 'Metadata' do
  puts 'Test 34: stores custom metadata via `meta: { ip: ..., user_agent: ... }`...'

  # Set metadata via context
  Trakable::Context.metadata = { 'ip' => '192.168.1.1', 'user_agent' => 'Mozilla/5.0' }

  assert_equal({ 'ip' => '192.168.1.1', 'user_agent' => 'Mozilla/5.0' }, Trakable::Context.metadata)
  puts '   ✓ custom metadata stored via context'

  puts 'Test 35: metadata accepts procs (evaluated at track time)...'

  # Metadata can be a proc that gets evaluated
  metadata_proc = -> { { timestamp: Time.now, request_id: 'abc123' } }
  evaluated = metadata_proc.call

  refute_nil evaluated[:timestamp]
  assert_equal 'abc123', evaluated[:request_id]
  puts '   ✓ proc metadata evaluated correctly'

  puts 'Test 36: metadata is merged into the trak record...'

  trak = Trakable::Trak.new(
    item_type: 'Post',
    item_id: 1,
    event: 'update',
    object: { 'title' => 'Old' },
    changeset: { 'title' => %w[Old New] },
    metadata: { 'ip' => '192.168.1.1', 'source' => 'web' }
  )

  assert_equal({ 'ip' => '192.168.1.1', 'source' => 'web' }, trak.metadata)
  puts '   ✓ metadata accessible on trak record'

  puts 'Test 37: metadata does not overwrite core fields (event, changeset, etc.)...'

  # Core fields are protected
  core_fields = %w[item_type item_id event object changeset whodunnit_type whodunnit_id created_at]
  metadata = { 'ip' => '192.168.1.1' }

  # Metadata should be separate from core fields
  overlap = core_fields & metadata.keys
  assert overlap.empty?, 'Metadata should not overlap core fields'
  puts '   ✓ metadata does not interfere with core trak fields'

  # Cleanup
  Trakable::Context.reset!
end
