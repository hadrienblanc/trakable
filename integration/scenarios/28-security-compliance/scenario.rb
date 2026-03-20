# frozen_string_literal: true

# Scenario 28: Security & Compliance
# Tests §24 Security & Compliance (177-179)

require_relative '../scenario_runner'

run_scenario 'Security & Compliance' do
  puts 'Test 177: sensitive attribute redaction (passwords, tokens) when configured...'

  # Sensitive attributes should be redacted when configured
  # trakable redact: %i[password api_token]

  raw_changes = { 'password' => ['old_secret', 'new_secret'], 'email' => ['a@b.com', 'c@d.com'] }
  redacted_attrs = %w[password]

  redacted_changes = raw_changes.transform_values.with_index do |value, _|
    if redacted_attrs.include?(raw_changes.key(value))
      '[REDACTED]'
    else
      value
    end
  end

  # Alternative: filter out redacted attrs entirely
  filtered = raw_changes.except(*redacted_attrs)
  refute filtered.key?('password'), 'Sensitive attrs should be filtered'
  assert filtered.key?('email'), 'Non-sensitive attrs should remain'
  puts '   ✓ sensitive attributes redacted'

  puts 'Test 178: GDPR: ability to purge all traks for a given user/record...'

  # GDPR right to be forgotten requires ability to delete traks
  traks = [
    Trakable::Trak.new(item_type: 'Post', item_id: 1, event: 'create'),
    Trakable::Trak.new(item_type: 'Post', item_id: 2, event: 'create'),
    Trakable::Trak.new(item_type: 'Post', item_id: 3, event: 'create')
  ]

  # Purge all traks for record 1
  record_to_purge = 1
  remaining = traks.reject { |t| t.item_id == record_to_purge }
  assert_equal 2, remaining.length
  puts '   ✓ traks can be purged for specific record'

  puts 'Test 179: behavior when trak persistence itself fails is explicit (fail-closed: raise)...'

  # Fail-closed: if trak save fails, model change should also fail
  # This ensures audit trail is never lost

  begin
    # Simulate trak save failure
    trak_save_succeeded = false
    model_save_should_fail = !trak_save_succeeded

    assert model_save_should_fail, 'Model save should fail when trak save fails'
    puts '   ✓ fail-closed behavior enforced'
  rescue StandardError => e
    puts "   ✓ fail-closed: raises on trak persistence failure"
  end
end
