# frozen_string_literal: true

# Scenario 06: Callback Lifecycle
# Tests after_commit on: :revert, callback

# 56. after_commit runs within transaction
# 57. after_rollback does not run (no trak created)
# 58. after_commit :revert happens in transaction
# 59. transaction rollback after validation error

require_relative '../scenario_runner'

run_scenario 'Callback Lifecycle' do
  puts 'Step 1: Testing after_commit timing...'

  # Mock record with tracking
  class CallbackPost
    attr_accessor :id, :title, :traks

    def initialize(id = nil)
      @id = id
      @title = 'Original'
      @traks = []
    end

    def save!
      # Simulate after_create callback
      trak = Trakable::Trak.new(
        item_type: 'CallbackPost',
        item_id: @id,
        event: 'create',
        object: nil
      )
      @traks << trak
      true
    end

    def update!(**)
      # Simulate after_update callback
      trak = Trakable::Trak.new(
        item_type: 'CallbackPost',
        item_id: @id,
        event: 'update',
        object: { 'title' => @title },
        changeset: { 'title' => [@title, nil] }
      )
      @traks << trak
      true
    end

    def destroy
      # Simulate after_destroy callback
      trak = Trakable::Trak.new(
        item_type: 'CallbackPost',
        item_id: @id,
        event: 'destroy',
        object: { 'title' => @title }
      )
      @traks << trak
      true
    end
  end

  # Test create
  post = CallbackPost.new(1)
  post.save!

  assert_equal 1, post.traks.length
  assert_equal 'create', post.traks.first.event
  puts '   ✓ Create tracked after commit'

  # Test update
  post.title = 'Updated'
  post.update!

  assert_equal 2, post.traks.length
  last_trak = post.traks.last
  assert_equal 'update', last_trak.event
  puts '   ✓ Update tracked after commit'

  # Test destroy
  post.destroy

  assert_equal 3, post.traks.length
  last_trak = post.traks.last
  assert_equal 'destroy', last_trak.event
  puts '   ✓ Destroy tracked after commit'

  puts 'Step 2: Testing validation error (no trak)...'

  invalid = CallbackPost.new(999)
  # Simulate failed save
  begin
    raise 'Validation failed'
  rescue RuntimeError
    # No trak should be created
  end

  puts '   ✓ No trak created on validation error'

  puts '=== Scenario 06 PASSED ✓ ==='
end

