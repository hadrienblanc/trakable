# frozen_string_literal: true

# Scenario 38: Concurrency
# Tests thread-safety of Context, Tracker, and trak creation under concurrent load

require_relative '../scenario_runner'

run_scenario 'Concurrency' do
  puts '=== TEST 1: Context isolation between threads ==='

  results = {}
  threads = 10.times.map do |i|
    Thread.new do
      user = "User_#{i}"
      Trakable::Context.with_user(user) do
        sleep(rand * 0.01) # Random delay to provoke interleaving
        results[i] = Trakable::Context.whodunnit
      end
    end
  end

  threads.each(&:join)

  10.times do |i|
    assert_equal "User_#{i}", results[i], "Thread #{i} saw wrong whodunnit: #{results[i]}"
  end
  puts '   ✓ Each thread sees its own whodunnit'

  puts '=== TEST 2: Context reset does not leak between threads ==='

  leak_detected = false
  barrier = Queue.new

  t1 = Thread.new do
    Trakable::Context.with_user('ThreadA') do
      barrier << :ready
      sleep 0.02
      leak_detected = true if Trakable::Context.whodunnit != 'ThreadA'
    end
  end

  t2 = Thread.new do
    barrier.pop # Wait for t1 to set context
    Trakable::Context.with_user('ThreadB') do
      sleep 0.01
    end
  end

  [t1, t2].each(&:join)
  refute leak_detected, 'Thread A context was corrupted by Thread B'
  puts '   ✓ Concurrent contexts do not leak'

  puts '=== TEST 3: without_tracking is thread-local ==='

  tracking_states = {}

  threads = 5.times.map do |i|
    Thread.new do
      if i.even?
        Trakable::Context.without_tracking do
          sleep(rand * 0.01)
          tracking_states[i] = Trakable::Context.tracking_enabled?
        end
      else
        sleep(rand * 0.01)
        tracking_states[i] = Trakable::Context.tracking_enabled?
      end
    end
  end

  threads.each(&:join)

  5.times do |i|
    if i.even?
      assert_equal false, tracking_states[i], "Thread #{i} should have tracking disabled"
    else
      assert_equal true, tracking_states[i], "Thread #{i} should have tracking enabled"
    end
  end
  puts '   ✓ without_tracking is thread-local'

  puts '=== TEST 4: Concurrent Tracker.call produces independent traks ==='

  records = 20.times.map do |i|
    record = Object.new
    record.define_singleton_method(:id) { i }
    record.define_singleton_method(:class) { Struct.new(:name).new("Post") }
    record.define_singleton_method(:previous_changes) { { 'title' => ["Old_#{i}", "New_#{i}"] } }
    record.define_singleton_method(:attributes) { { 'id' => i, 'title' => "New_#{i}" } }
    record
  end

  traks = []
  mutex = Mutex.new

  threads = records.map do |record|
    Thread.new do
      trak = Trakable::Tracker.call(record, 'update')
      mutex.synchronize { traks << trak }
    end
  end

  threads.each(&:join)

  assert_equal 20, traks.length, "Expected 20 traks, got #{traks.length}"

  item_ids = traks.map(&:item_id).sort
  assert_equal (0..19).to_a, item_ids, 'Each record should have exactly one trak'
  puts '   ✓ 20 concurrent Tracker.call produce 20 independent traks'

  puts '=== TEST 5: Concurrent whodunnit assignment per thread ==='

  traks = []
  mutex = Mutex.new

  threads = 10.times.map do |i|
    Thread.new do
      actor = Struct.new(:id, :class).new(i, Struct.new(:name).new("Actor"))
      Trakable::Context.with_user(actor) do
        record = Object.new
        record.define_singleton_method(:id) { i }
        record.define_singleton_method(:class) { Struct.new(:name).new("Post") }
        record.define_singleton_method(:previous_changes) { { 'title' => ['a', 'b'] } }
        record.define_singleton_method(:attributes) { { 'id' => i, 'title' => 'b' } }

        trak = Trakable::Tracker.call(record, 'update')
        mutex.synchronize { traks << trak }
      end
    end
  end

  threads.each(&:join)

  traks.each do |trak|
    assert_equal trak.item_id, trak.whodunnit_id,
                 "Trak for item #{trak.item_id} has whodunnit #{trak.whodunnit_id}"
  end
  puts '   ✓ Each thread whodunnit is correctly paired with its trak'

  puts '=== TEST 6: Stress test — 100 threads ==='

  traks = []
  mutex = Mutex.new

  threads = 100.times.map do |i|
    Thread.new do
      record = Object.new
      record.define_singleton_method(:id) { i }
      record.define_singleton_method(:class) { Struct.new(:name).new("StressModel") }
      record.define_singleton_method(:previous_changes) { {} }
      record.define_singleton_method(:attributes) { { 'id' => i } }

      trak = Trakable::Tracker.call(record, 'create')
      mutex.synchronize { traks << trak }
    end
  end

  threads.each(&:join)

  assert_equal 100, traks.length
  assert_equal 100, traks.map(&:item_id).uniq.length, 'All 100 traks should be unique'
  puts '   ✓ 100 concurrent threads produce 100 unique traks'
end
