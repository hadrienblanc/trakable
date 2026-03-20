# frozen_string_literal: true

# Scenario 36: Whodunnit Deep Tests
# Tests who made the changes with various scenarios

require_relative '../scenario_runner'

# Simulated actor (user, admin, api key, etc.)
class Actor
  attr_reader :id, :type, :name

  def initialize(id, type, name)
    @id = id
    @type = type
    @name = name
  end

  def to_s
    "#{type}##{id}(#{name})"
  end

  def ==(other)
    other.is_a?(Actor) && @id == other.id && @type == other.type
  end
end

# Simulated trak with whodunnit
class WhodunnitTrak
  attr_reader :event, :whodunnit_type, :whodunnit_id, :timestamp, :changeset

  def initialize(event:, whodunnit:, changeset:, timestamp: Time.now)
    @event = event
    @whodunnit_type = whodunnit&.type
    @whodunnit_id = whodunnit&.id
    @changeset = changeset
    @timestamp = timestamp
  end

  def whodunnit
    return nil unless @whodunnit_type && @whodunnit_id

    # Simulate finding the actor
    Actor.new(@whodunnit_id, @whodunnit_type, "Found #{@whodunnit_type}")
  end

  def anonymous?
    @whodunnit_type.nil? || @whodunnit_id.nil?
  end
end

# Simulated tracked item with whodunnit
class WhodunnitPost
  attr_accessor :id, :title, :traks

  def initialize(id:, title:)
    @id = id
    @title = title
    @traks = []
  end

  def update!(new_title, actor:)
    old_title = @title
    @title = new_title

    trak = WhodunnitTrak.new(
      event: 'update',
      whodunnit: actor,
      changeset: { 'title' => [old_title, new_title] }
    )
    @traks << trak
    trak
  end

  def create!(actor:)
    trak = WhodunnitTrak.new(
      event: 'create',
      whodunnit: actor,
      changeset: { 'title' => [@title] }
    )
    @traks << trak
    trak
  end

  def destroy!(actor:)
    trak = WhodunnitTrak.new(
      event: 'destroy',
      whodunnit: actor,
      changeset: {}
    )
    @traks << trak
    trak
  end

  def changes_by(actor_type)
    @traks.select { |t| t.whodunnit_type == actor_type.to_s }
  end

  def changes_by_id(actor_id)
    @traks.select { |t| t.whodunnit_id == actor_id }
  end
end

run_scenario 'Whodunnit Deep Tests' do
  puts '=== TEST 1: Basic whodunnit - User makes a change ==='

  alice = Actor.new(1, 'User', 'Alice')
  post = WhodunnitPost.new(id: 1, title: 'Hello')
  post.create!(actor: alice)

  trak = post.traks.last
  assert_equal 'User', trak.whodunnit_type
  assert_equal 1, trak.whodunnit_id
  puts '   ✓ User tracked as whodunnit'

  puts '=== TEST 2: Polymorphic whodunnit - Different actor types ==='

  bob = Actor.new(2, 'User', 'Bob')
  admin = Actor.new(1, 'Admin', 'SuperAdmin')
  api_key = Actor.new(99, 'ApiKey', 'system-key')

  post = WhodunnitPost.new(id: 2, title: 'Initial')
  post.create!(actor: bob)
  post.update!('Updated by admin', actor: admin)
  post.update!('Updated by API', actor: api_key)

  assert_equal 3, post.traks.length
  assert_equal 'User', post.traks[0].whodunnit_type
  assert_equal 'Admin', post.traks[1].whodunnit_type
  assert_equal 'ApiKey', post.traks[2].whodunnit_type
  puts '   ✓ Polymorphic whodunnit tracked correctly'

  puts '=== TEST 3: Anonymous changes (no whodunnit) ==='

  post = WhodunnitPost.new(id: 3, title: 'Anonymous')
  post.create!(actor: nil)

  trak = post.traks.last
  assert trak.anonymous?
  assert_nil trak.whodunnit_type
  assert_nil trak.whodunnit_id
  puts '   ✓ Anonymous changes tracked with nil whodunnit'

  puts '=== TEST 4: Query changes by actor type ==='

  post = WhodunnitPost.new(id: 4, title: 'Start')
  post.create!(actor: Actor.new(1, 'User', 'U1'))
  post.update!('V1', actor: Actor.new(1, 'Admin', 'A1'))
  post.update!('V2', actor: Actor.new(2, 'User', 'U2'))
  post.update!('V3', actor: Actor.new(1, 'Admin', 'A1'))

  user_changes = post.changes_by('User')
  admin_changes = post.changes_by('Admin')

  assert_equal 2, user_changes.length
  assert_equal 2, admin_changes.length
  puts '   ✓ Can query changes by actor type'

  puts '=== TEST 5: Query changes by specific actor ID ==='

  alice = Actor.new(1, 'User', 'Alice')
  bob = Actor.new(2, 'User', 'Bob')

  post = WhodunnitPost.new(id: 5, title: 'Start')
  post.create!(actor: alice)
  post.update!('By Alice', actor: alice)
  post.update!('By Bob', actor: bob)
  post.update!('By Alice again', actor: alice)

  alice_changes = post.changes_by_id(1)
  bob_changes = post.changes_by_id(2)

  assert_equal 3, alice_changes.length
  assert_equal 1, bob_changes.length
  puts '   ✓ Can query changes by specific actor ID'

  puts '=== TEST 6: Fuzzy - Many users editing same record ==='

  users = 20.times.map { |i| Actor.new(i + 1, 'User', "User#{i + 1}") }
  post = WhodunnitPost.new(id: 6, title: 'Collaborative')
  post.create!(actor: users.first) # Initial create

  100.times do
    random_user = users.sample
    post.update!("Edit by #{random_user.name}", actor: random_user)
  end

  assert_equal 101, post.traks.length # create + 100 updates

  # Count edits per user
  edits_per_user = Hash.new(0)
  post.traks.each do |t|
    edits_per_user[t.whodunnit_id] += 1 if t.whodunnit_id
  end

  total_edits = edits_per_user.values.sum
  assert_equal 101, total_edits
  puts '   ✓ 100 random edits by 20 users tracked correctly'

  puts '=== TEST 7: Fuzzy - Actor type distribution ==='

  post = WhodunnitPost.new(id: 7, title: 'Stats')
  actor_types = %w[User Admin System ApiKey]

  1000.times do
    type = actor_types.sample
    id = rand(1..10)
    actor = Actor.new(id, type, "#{type}##{id}")
    post.update!("Edit", actor: actor)
  end

  # Verify distribution
  type_counts = Hash.new(0)
  post.traks.each { |t| type_counts[t.whodunnit_type] += 1 }

  # Each type should have some edits (very likely with 1000 samples)
  actor_types.each do |type|
    assert type_counts[type] > 0, "#{type} should have at least one edit"
  end
  puts '   ✓ 1000 edits distributed across actor types'

  puts '=== TEST 8: Thread safety - Concurrent actor contexts ==='

  results = []
  threads = []

  10.times do |i|
    threads << Thread.new do
      user = Actor.new(i, 'User', "Thread#{i}")
      post = WhodunnitPost.new(id: 100 + i, title: "Thread Post #{i}")
      trak = post.create!(actor: user)
      results << [i, trak.whodunnit_id, trak.whodunnit_type]
    end
  end

  threads.each(&:join)

  results.each do |thread_id, whodunnit_id, whodunnit_type|
    assert_equal thread_id, whodunnit_id
    assert_equal 'User', whodunnit_type
  end
  puts '   ✓ Thread-safe whodunnit tracking works'

  puts '=== TEST 9: Whodunnit chain of custody ==='

  alice = Actor.new(1, 'User', 'Alice')
  bob = Actor.new(2, 'User', 'Bob')
  admin = Actor.new(1, 'Admin', 'Admin')

  post = WhodunnitPost.new(id: 8, title: 'Chain')
  post.create!(actor: alice)
  post.update!('Edit 1', actor: bob)
  post.update!('Edit 2', actor: admin)
  post.destroy!(actor: alice)

  # Verify chain
  assert_equal 1, post.traks[0].whodunnit_id
  assert_equal 2, post.traks[1].whodunnit_id
  assert_equal 1, post.traks[2].whodunnit_id
  assert_equal 1, post.traks[3].whodunnit_id
  puts '   ✓ Complete chain of custody tracked'

  puts '=== TEST 10: Who made the most edits? ==='

  post = WhodunnitPost.new(id: 9, title: 'Competition')
  users = 5.times.map { |i| Actor.new(i + 1, 'User', "User#{i + 1}") }

  50.times do
    user = users.sample
    post.update!("Edit", actor: user)
  end

  # Count edits per user
  edits_per_user = Hash.new(0)
  post.traks.each { |t| edits_per_user[t.whodunnit_id] += 1 if t.whodunnit_id }

  top_editor = edits_per_user.max_by { |_, count| count }
  refute_nil top_editor
  puts "   ✓ Top editor is User##{top_editor[0]} with #{top_editor[1]} edits"

  puts "\n=== Scenario 36: Whodunnit Deep Tests PASSED ✓ ==="
end
