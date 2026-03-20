# frozen_string_literal: true

# Scenario 40: Whodunnit Config
# Tests config.whodunnit_method global configuration

require_relative '../scenario_runner'

run_scenario 'Whodunnit Config' do
  puts '=== TEST 1: Default whodunnit_method is :current_user ==='

  assert_equal :current_user, Trakable.configuration.whodunnit_method
  puts '   ✓ Default is :current_user'

  puts '=== TEST 2: whodunnit_method is configurable ==='

  Trakable.configure do |config|
    config.whodunnit_method = :current_admin
  end

  assert_equal :current_admin, Trakable.configuration.whodunnit_method
  puts '   ✓ Changed to :current_admin'

  puts '=== TEST 3: Controller reads from global config ==='

  # Simulate a controller that uses the configured method
  controller_class = Class.new do
    attr_accessor :current_admin

    def whodunnit_method
      Trakable.configuration.whodunnit_method
    end

    def perform_action(&block)
      user = send(whodunnit_method)
      Trakable.with_user(user, &block)
    end
  end

  admin = Struct.new(:id, :class).new(42, Struct.new(:name).new('Admin'))
  controller = controller_class.new
  controller.current_admin = admin

  controller.perform_action do
    assert_equal admin, Trakable::Context.whodunnit
  end
  puts '   ✓ Controller uses configured method'

  puts '=== TEST 4: Tracker picks up whodunnit from context ==='

  actor = Struct.new(:id, :class).new(99, Struct.new(:name).new('Admin'))

  Trakable::Context.with_user(actor) do
    record = Object.new
    record.define_singleton_method(:id) { 1 }
    record.define_singleton_method(:class) { Struct.new(:name).new('Post') }
    record.define_singleton_method(:previous_changes) { { 'title' => %w[Old New] } }
    record.define_singleton_method(:attributes) { { 'id' => 1, 'title' => 'New' } }

    trak = Trakable::Tracker.call(record, 'update')

    assert_equal 'Admin', trak.whodunnit_type
    assert_equal 99, trak.whodunnit_id
  end
  puts '   ✓ Tracker records whodunnit from context'

  puts '=== TEST 5: Different whodunnit types (polymorphic) ==='

  actor_types = [
    Struct.new(:id, :class).new(1, Struct.new(:name).new('User')),
    Struct.new(:id, :class).new(2, Struct.new(:name).new('Admin')),
    Struct.new(:id, :class).new(3, Struct.new(:name).new('ApiKey')),
    Struct.new(:id, :class).new(4, Struct.new(:name).new('ServiceAccount'))
  ]

  traks = actor_types.map do |actor|
    Trakable::Context.with_user(actor) do
      record = Object.new
      record.define_singleton_method(:id) { actor.id }
      record.define_singleton_method(:class) { Struct.new(:name).new('Post') }
      record.define_singleton_method(:previous_changes) { { 'x' => [0, 1] } }
      record.define_singleton_method(:attributes) { { 'id' => actor.id } }

      Trakable::Tracker.call(record, 'update')
    end
  end

  types = traks.map(&:whodunnit_type)
  assert_equal %w[User Admin ApiKey ServiceAccount], types
  puts '   ✓ Works with User, Admin, ApiKey, ServiceAccount'

  puts '=== TEST 6: Nil whodunnit (anonymous/system changes) ==='

  record = Object.new
  record.define_singleton_method(:id) { 1 }
  record.define_singleton_method(:class) { Struct.new(:name).new('Post') }
  record.define_singleton_method(:previous_changes) { { 'status' => [0, 1] } }
  record.define_singleton_method(:attributes) { { 'id' => 1 } }

  trak = Trakable::Tracker.call(record, 'update')

  assert_nil trak.whodunnit_type
  assert_nil trak.whodunnit_id
  puts '   ✓ Anonymous changes have nil whodunnit'

  puts '=== TEST 7: Reset config ==='

  Trakable.configure do |config|
    config.whodunnit_method = :current_user
  end

  assert_equal :current_user, Trakable.configuration.whodunnit_method
  puts '   ✓ Config reset to default'
end
