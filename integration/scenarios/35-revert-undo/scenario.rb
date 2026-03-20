# frozen_string_literal: true

# Scenario 35: Revert / Undo Tests
# Tests going back to previous states

require_relative '../scenario_runner'

# Simulated state storage
class StateHistory
  class << self
    def states
      @states ||= []
    end

    def push(state)
      states << { state: state.dup, at: Time.now }
    end

    def current
      states.last&.dig(:state) || {}
    end

    def at(index)
      states[index]&.dig(:state)
    end

    def rollback_to(index)
      @states = states[0..index]
      current
    end

    def clear
      @states = []
    end
  end
end

# Simulated tracked model
class RevertiblePost
  attr_accessor :id, :title, :body, :status, :views

  def initialize(id: nil, title: '', body: '', status: 'draft', views: 0)
    @id = id
    @title = title
    @body = body
    @status = status
    @views = views
    StateHistory.push(attributes)
  end

  def attributes
    { 'id' => @id, 'title' => @title, 'body' => @body, 'status' => @status, 'views' => @views }
  end

  def update!(new_attrs)
    new_attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    StateHistory.push(attributes)
  end

  def destroy
    StateHistory.push(attributes.merge('_destroyed' => true))
  end

  # Go back to a previous state
  def revert_to!(state_index)
    previous = StateHistory.at(state_index)
    return nil unless previous

    previous.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    StateHistory.push(attributes)
    self
  end

  # Undo last change
  def undo!
    return nil if StateHistory.states.length < 2

    StateHistory.states.pop # Remove current
    previous = StateHistory.current
    previous.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    self
  end

  def history
    StateHistory.states.map { |s| s[:state] }
  end

  def destroyed?
    StateHistory.current['_destroyed'] == true
  end
end

run_scenario 'Revert / Undo Tests' do
  puts '=== TEST 1: Basic undo (go back one step) ==='

  StateHistory.clear
  post = RevertiblePost.new(id: 1, title: 'Version 1')

  post.update!('title' => 'Version 2')
  post.update!('title' => 'Version 3')

  assert_equal 'Version 3', post.title
  assert_equal 3, post.history.length

  post.undo!
  assert_equal 'Version 2', post.title
  puts '   ✓ Undo goes back one step'

  puts '=== TEST 2: Revert to specific version ==='

  StateHistory.clear
  post = RevertiblePost.new(id: 2, title: 'Original', status: 'draft')

  post.update!('title' => 'Edited', 'status' => 'review')
  post.update!('title' => 'Final', 'status' => 'published')
  post.update!('views' => 100)

  # Revert to version 2 (index 1)
  post.revert_to!(1)
  assert_equal 'Edited', post.title
  assert_equal 'review', post.status
  puts '   ✓ Revert to specific version works'

  puts '=== TEST 3: Revert create = destroy ==='

  StateHistory.clear
  post = RevertiblePost.new(id: 3, title: 'To be destroyed')

  post.destroy
  assert post.destroyed?
  puts '   ✓ Destroy creates a destroyed state'

  puts '=== TEST 4: Revert destroy = restore ==='

  StateHistory.clear
  post = RevertiblePost.new(id: 4, title: 'Will be restored')

  post.update!('title' => 'Updated')
  post.destroy

  # Revert to before destroy
  post.revert_to!(1) # Index 1 = "Updated" state
  refute post.destroyed?
  assert_equal 'Updated', post.title
  puts '   ✓ Revert from destroy restores record'

  puts '=== TEST 5: Multiple undos in sequence ==='

  StateHistory.clear
  post = RevertiblePost.new(id: 5, title: 'Step 0')

  post.update!('title' => 'Step 1')
  post.update!('title' => 'Step 2')
  post.update!('title' => 'Step 3')
  post.update!('title' => 'Step 4')

  4.times { post.undo! }
  assert_equal 'Step 0', post.title
  puts '   ✓ Multiple undos work correctly'

  puts '=== TEST 6: Fuzzy - Random updates then verify history ==='

  StateHistory.clear
  post = RevertiblePost.new(id: 6, title: 'Start')

  titles = ['Start']
  50.times do
    new_title = "Title #{rand(1000)}"
    titles << new_title
    post.update!('title' => new_title)
  end

  # Verify history
  post.history.each_with_index do |state, i|
    assert_equal titles[i], state['title'], "History mismatch at index #{i}"
  end
  puts '   ✓ 50 random updates preserved correctly in history'

  puts '=== TEST 7: Fuzzy - Revert to random points ==='

  10.times do
    StateHistory.clear
    post = RevertiblePost.new(id: 7, title: 'A', views: 0)

    # Create some history - state[i] will have views = i
    # State 0: views=0 (initial)
    # State 1: views=1 (after update with i=1)
    # ...
    20.times { |i| post.update!('views' => i + 1) }

    # Revert to random point
    target = rand(0..20)
    post.revert_to!(target)
    assert_equal target, post.views
  end
  puts '   ✓ Random reverts work correctly (10 iterations)'

  puts '=== TEST 8: Edge case - Revert to non-existent version ==='

  StateHistory.clear
  post = RevertiblePost.new(id: 9, title: 'Only')

  result = post.revert_to!(999)
  assert_nil result
  puts '   ✓ Revert to non-existent version returns nil'

  puts '=== TEST 9: Edge case - Undo on fresh record ==='

  StateHistory.clear
  post = RevertiblePost.new(id: 10, title: 'Fresh')

  result = post.undo! # Only 1 state, can't undo
  assert_equal 'Fresh', post.title # Should stay the same
  puts '   ✓ Undo on fresh record handles gracefully'

  puts '=== TEST 10: Chain of custody ==='

  StateHistory.clear
  post = RevertiblePost.new(id: 11, title: 'Chain')

  post.update!('title' => 'Link 1')
  post.update!('title' => 'Link 2')
  post.update!('title' => 'Link 3')

  # Verify we can trace back through all states
  history = post.history
  assert_equal 4, history.length
  assert_equal 'Chain', history[0]['title']
  assert_equal 'Link 1', history[1]['title']
  assert_equal 'Link 2', history[2]['title']
  assert_equal 'Link 3', history[3]['title']
  puts '   ✓ Complete chain of custody available'

  puts "\n=== Scenario 35: Revert / Undo Tests PASSED ✓ ==="
end
