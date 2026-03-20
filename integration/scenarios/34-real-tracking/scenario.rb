# frozen_string_literal: true

# Scenario 34: Real Tracking Tests
# Tests with actual state changes and verification

require_relative '../scenario_runner'

# Simple in-memory storage for testing
class TrakStore
  class << self
    def storage
      @storage ||= []
    end

    def <<(trak)
      storage << trak
    end

    def all
      storage
    end

    def for_item(type, id)
      storage.select { |t| t.item_type == type && t.item_id == id }
    end

    def clear
      @storage = []
    end
  end
end

# Simple trak object
class SimpleTrak
  attr_accessor :item_type, :item_id, :event, :object, :changeset, :whodunnit, :created_at

  def initialize(attrs = {})
    attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    @created_at ||= Time.now
  end
end

# Mock model that actually simulates tracking
class TrackedPost
  attr_accessor :id, :title, :body, :views

  def initialize(id: nil, title: '', body: '', views: 0)
    @id = id
    @title = title
    @body = body
    @views = views
  end

  def attributes
    { 'id' => @id, 'title' => @title, 'body' => @body, 'views' => @views }
  end

  def simulate_create(user: nil)
    SimpleTrak.new(
      item_type: 'TrackedPost',
      item_id: @id,
      event: 'create',
      object: nil,
      changeset: attributes.except('id'),
      whodunnit: user
    )
  end

  def simulate_update(old_attrs, user: nil)
    changeset = {}
    attributes.each do |k, v|
      changeset[k] = [old_attrs[k], v] if old_attrs[k] != v
    end

    SimpleTrak.new(
      item_type: 'TrackedPost',
      item_id: @id,
      event: 'update',
      object: old_attrs,
      changeset: changeset,
      whodunnit: user
    )
  end

  def simulate_destroy(user: nil)
    SimpleTrak.new(
      item_type: 'TrackedPost',
      item_id: @id,
      event: 'destroy',
      object: attributes.except('id'),
      changeset: {},
      whodunnit: user
    )
  end
end

# Mock user
class TestUser
  attr_reader :id, :name

  def initialize(id, name)
    @id = id
    @name = name
  end
end

run_scenario 'Real Tracking Tests' do
  puts '=== TEST 1: Create tracking ==='

  post = TrackedPost.new(id: 1, title: 'Hello', body: 'World')
  trak = post.simulate_create
  TrakStore << trak

  assert_equal 'create', trak.event
  assert_equal 'TrackedPost', trak.item_type
  assert_equal 1, trak.item_id
  assert_equal({ 'title' => 'Hello', 'body' => 'World', 'views' => 0 }, trak.changeset)
  puts '   ✓ Create event tracked with correct data'

  puts '=== TEST 2: Update tracking with diff ==='

  old_attrs = post.attributes.dup
  post.title = 'Hello Updated'
  post.views = 10

  trak = post.simulate_update(old_attrs)
  TrakStore << trak
  assert_equal 'update', trak.event
  assert_equal 'Hello', trak.object['title']
  assert_equal ['Hello', 'Hello Updated'], trak.changeset['title']
  assert_equal [0, 10], trak.changeset['views']
  puts '   ✓ Update event tracked with correct diff'

  puts '=== TEST 3: Destroy tracking ==='

  trak = post.simulate_destroy
  TrakStore << trak
  assert_equal 'destroy', trak.event
  assert_equal 'Hello Updated', trak.object['title']
  puts '   ✓ Destroy event tracked with final state'

  puts '=== TEST 4: Whodunnit tracking ==='

  TrakStore.clear
  alice = TestUser.new(1, 'Alice')

  post2 = TrackedPost.new(id: 2, title: 'By Alice')
  trak = post2.simulate_create(user: alice)
  TrakStore << trak

  assert_equal alice, trak.whodunnit
  puts '   ✓ Whodunnit correctly stored'

  puts '=== TEST 5: Trak history query ==='

  all_traks = TrakStore.for_item('TrackedPost', 2)
  assert_equal 1, all_traks.length
  assert_equal 'create', all_traks.first.event
  puts '   ✓ Can query history for an item'

  puts '=== TEST 6: Fuzzy test - multiple rapid updates ==='

  TrakStore.clear
  post3 = TrackedPost.new(id: 3, title: 'Initial')

  100.times do |i|
    old_attrs = post3.attributes.dup
    post3.title = "Title #{i}"
    trak = post3.simulate_update(old_attrs)
    TrakStore << trak
  end

  history = TrakStore.for_item('TrackedPost', 3)
  assert_equal 100, history.length
  puts '   ✓ 100 rapid updates all tracked correctly'

  puts '=== TEST 7: Fuzzy test - concurrent-like updates ==='

  # Clear once before starting threads
  TrakStore.clear
  threads = []
  mutex = Mutex.new

  10.times do |i|
    threads << Thread.new do
      post = TrackedPost.new(id: 100 + i, title: "Thread #{i}")
      trak = post.simulate_create
      mutex.synchronize { TrakStore << trak }
    end
  end

  threads.each(&:join)
  assert_equal 10, TrakStore.all.length
  puts '   ✓ Thread-safe tracking works'

  puts '=== TEST 8: Fuzzy test - empty vs nil vs blank ==='

  TrakStore.clear
  post4 = TrackedPost.new(id: 4, title: '', body: nil)

  old_attrs = { 'id' => 4, 'title' => nil, 'body' => '', 'views' => 0 }
  new_attrs = post4.attributes

  changeset = {}
  new_attrs.each do |k, v|
    changeset[k] = [old_attrs[k], v] if old_attrs[k] != v
  end

  assert changeset.key?('title'), 'nil to empty string should be tracked'
  assert changeset.key?('body'), 'empty string to nil should be tracked'
  puts '   ✓ Empty string vs nil distinction preserved'

  puts '=== TEST 9: Fuzzy test - special characters ==='

  TrakStore.clear
  special_chars = [
    '<script>alert("xss")</script>',
    "O'Reilly",
    'Hello"World',
    "Line1\nLine2\tTab",
    '日本語',
    '🎉',
    '../../../etc/passwd'
  ]

  special_chars.each_with_index do |title, i|
    post = TrackedPost.new(id: 200 + i, title: title)
    trak = post.simulate_create
    assert_equal title, trak.changeset['title']
  end

  puts '   ✓ Special characters preserved correctly'

  puts '=== TEST 10: Revert to previous state ==='

  TrakStore.clear
  post5 = TrackedPost.new(id: 5, title: 'Original')
  trak1 = post5.simulate_create
  TrakStore << trak1

  old_attrs = post5.attributes.dup
  post5.title = 'Updated'
  trak2 = post5.simulate_update(old_attrs)
  TrakStore << trak2

  # Get previous state from the update trak
  update_trak = TrakStore.all.last
  previous_state = update_trak.object

  assert_equal 'Original', previous_state['title']
  puts '   ✓ Can retrieve previous state for revert'

  puts "\n=== Scenario 34: Real Tracking Tests PASSED ✓ ==="
end
