# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/test/'
  add_group 'Library', 'lib'
end

require 'active_record'
require 'minitest/autorun'

# --- In-memory SQLite setup ---

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define do
  create_table :traks, force: true do |t|
    t.string   :item_type,      null: false
    t.bigint   :item_id,        null: false
    t.string   :event,          null: false
    t.text     :object
    t.text     :changeset
    t.string   :whodunnit_type
    t.bigint   :whodunnit_id
    t.text     :metadata
    t.datetime :created_at, null: false
  end

  add_index :traks, %i[item_type item_id]
  add_index :traks, :created_at
  add_index :traks, %i[whodunnit_type whodunnit_id]
  add_index :traks, :event
  add_index :traks, %i[item_type created_at]

  create_table :posts, force: true do |t|
    t.string  :title
    t.text    :body
    t.integer :status, default: 0
    t.integer :views_count, default: 0
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :comments, force: true do |t|
    t.bigint :post_id, null: false
    t.text   :content
    t.timestamps
  end
end

require 'trakable'

# --- AR Models ---

class User < ActiveRecord::Base; end

class Post < ActiveRecord::Base
  include Trakable::Model

  trakable only: %i[title body status]
end

class Comment < ActiveRecord::Base
  include Trakable::Model

  belongs_to :post

  trakable
end

# Model with conditional tracking
class ConditionalPost < ActiveRecord::Base
  self.table_name = 'posts'
  include Trakable::Model

  trakable if: -> { status.to_i.positive? }
end

# Model tracking only specific events
class CreateOnlyPost < ActiveRecord::Base
  self.table_name = 'posts'
  include Trakable::Model

  trakable on: %i[create]
end

# Model with max_traks
class LimitedPost < ActiveRecord::Base
  self.table_name = 'posts'
  include Trakable::Model

  trakable max_traks: 3
end

# Model with retention
class RetainedPost < ActiveRecord::Base
  self.table_name = 'posts'
  include Trakable::Model

  trakable retention: 30 * 24 * 60 * 60 # 30 days
end

# Model with ignore
class IgnorePost < ActiveRecord::Base
  self.table_name = 'posts'
  include Trakable::Model

  trakable ignore: %i[views_count]
end

# --- Base test class ---

class IntegrationTest < Minitest::Test
  def setup
    Trakable::Context.reset!
    Trakable.configuration.enabled = true
  end

  def teardown
    Trakable::Context.reset!
    Trakable.configuration.enabled = true
    Trakable.configuration.ignored_attrs = %w[created_at updated_at id]
    Trakable::Trak.delete_all
    Post.delete_all
    User.delete_all
    Comment.delete_all
  end
end

# ============================================================
# 1. Basic lifecycle: create / update / destroy
# ============================================================
class LifecycleTest < IntegrationTest
  def test_create_generates_trak
    post = Post.create!(title: 'Hello', body: 'World')

    traks = Trakable::Trak.where(item_type: 'Post', item_id: post.id)
    assert_equal 1, traks.count

    trak = traks.first
    assert_equal 'create', trak.event
    assert trak.create?
    assert_equal({ 'title' => [nil, 'Hello'], 'body' => [nil, 'World'] }, trak.changeset)
    assert_nil trak.object
  end

  def test_update_generates_trak_with_changeset
    post = Post.create!(title: 'V1', body: 'B')
    post.update!(title: 'V2')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'update').last
    assert_equal({ 'title' => ['V1', 'V2'] }, trak.changeset)
    assert_equal 'V1', trak.object['title']
  end

  def test_destroy_generates_trak_with_full_snapshot
    post = Post.create!(title: 'Bye', body: 'Gone')
    post_id = post.id
    post.destroy!

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post_id, event: 'destroy').last
    assert trak
    assert_equal({}, trak.changeset)
    assert_equal 'Bye', trak.object['title']
    assert_equal 'Gone', trak.object['body']
  end

  def test_full_lifecycle_produces_three_traks
    post = Post.create!(title: 'A', body: 'B')
    post.update!(title: 'C')
    post_id = post.id
    post.destroy!

    traks = Trakable::Trak.where(item_type: 'Post', item_id: post_id).order(:created_at)
    assert_equal 3, traks.count
    assert_equal %w[create update destroy], traks.map(&:event)
  end

  def test_traks_survive_record_destruction
    post = Post.create!(title: 'Survive', body: 'Me')
    post_id = post.id
    post.destroy!

    count = Trakable::Trak.where(item_type: 'Post', item_id: post_id).count
    assert_equal 2, count
  end

  def test_multiple_updates_each_produce_a_trak
    post = Post.create!(title: 'V0', body: 'B')
    10.times { |i| post.update!(title: "V#{i + 1}") }

    traks = Trakable::Trak.where(item_type: 'Post', item_id: post.id)
    assert_equal 11, traks.count # 1 create + 10 updates
  end
end

# ============================================================
# 2. Filtering: only / ignore / global ignored_attrs
# ============================================================
class FilteringTest < IntegrationTest
  def test_only_filters_changeset
    post = Post.create!(title: 'T', body: 'B')
    post.update!(title: 'T2', views_count: 99)

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'update').last
    assert trak.changeset.key?('title')
    refute trak.changeset.key?('views_count')
  end

  def test_update_on_non_tracked_attr_creates_no_trak
    post = Post.create!(title: 'T', body: 'B')
    count_before = Trakable::Trak.count
    post.update!(views_count: 42)
    count_after = Trakable::Trak.count

    assert_equal count_before, count_after
  end

  def test_ignore_option_filters_out_attribute
    post = IgnorePost.create!(title: 'T', body: 'B', views_count: 5)
    post.update!(title: 'T2', views_count: 10)

    trak = Trakable::Trak.where(item_type: 'IgnorePost', item_id: post.id, event: 'update').last
    assert trak.changeset.key?('title')
    refute trak.changeset.key?('views_count')
  end

  def test_global_ignored_attrs_are_excluded
    post = Post.create!(title: 'T', body: 'B')
    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'create').last

    refute trak.changeset.key?('created_at')
    refute trak.changeset.key?('updated_at')
    refute trak.changeset.key?('id')
  end
end

# ============================================================
# 3. Conditional tracking: if / unless
# ============================================================
class ConditionalTrackingTest < IntegrationTest
  def test_if_condition_skips_when_false
    post = ConditionalPost.create!(title: 'Draft', body: 'B', status: 0)

    traks = Trakable::Trak.where(item_type: 'ConditionalPost', item_id: post.id)
    assert_equal 0, traks.count
  end

  def test_if_condition_tracks_when_true
    post = ConditionalPost.create!(title: 'Published', body: 'B', status: 1)

    traks = Trakable::Trak.where(item_type: 'ConditionalPost', item_id: post.id)
    assert_equal 1, traks.count
  end
end

# ============================================================
# 4. Event selection: on: [:create]
# ============================================================
class EventSelectionTest < IntegrationTest
  def test_on_create_only_tracks_create
    post = CreateOnlyPost.create!(title: 'T', body: 'B')
    post.update!(title: 'T2')
    post.destroy!

    traks = Trakable::Trak.where(item_type: 'CreateOnlyPost')
    assert_equal 1, traks.count
    assert_equal 'create', traks.first.event
  end
end

# ============================================================
# 5. Whodunnit (polymorphic)
# ============================================================
class WhodunnitTest < IntegrationTest
  def test_whodunnit_records_user
    user = User.create!(name: 'Alice')
    Trakable::Context.whodunnit = user

    post = Post.create!(title: 'T', body: 'B')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id).last
    assert_equal 'User', trak.whodunnit_type
    assert_equal user.id, trak.whodunnit_id
    assert_equal user, trak.whodunnit
  end

  def test_whodunnit_nil_when_not_set
    post = Post.create!(title: 'T', body: 'B')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id).last
    assert_nil trak.whodunnit_type
    assert_nil trak.whodunnit_id
    assert_nil trak.whodunnit
  end

  def test_whodunnit_returns_nil_when_user_deleted
    user = User.create!(name: 'Ghost')
    Trakable::Context.whodunnit = user
    post = Post.create!(title: 'T', body: 'B')
    user.destroy!

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id).last
    assert_equal 'User', trak.whodunnit_type
    assert_nil trak.whodunnit
  end

  def test_with_user_block
    user = User.create!(name: 'Bob')

    Trakable.with_user(user) do
      Post.create!(title: 'T', body: 'B')
    end

    trak = Trakable::Trak.last
    assert_equal user.id, trak.whodunnit_id

    # Context cleaned up
    assert_nil Trakable::Context.whodunnit
  end
end

# ============================================================
# 6. Metadata
# ============================================================
class MetadataTest < IntegrationTest
  def test_metadata_stored_and_retrieved
    Trakable::Context.metadata = { 'ip' => '10.0.0.1', 'ua' => 'Test' }
    post = Post.create!(title: 'T', body: 'B')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id).last
    assert_equal({ 'ip' => '10.0.0.1', 'ua' => 'Test' }, trak.metadata)
  end

  def test_metadata_nil_by_default
    post = Post.create!(title: 'T', body: 'B')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id).last
    assert_nil trak.metadata
  end
end

# ============================================================
# 7. Scopes
# ============================================================
class ScopesTest < IntegrationTest
  def test_for_item_type
    Post.create!(title: 'T', body: 'B')
    Comment.create!(post_id: 1, content: 'C')

    assert_equal 1, Trakable::Trak.for_item_type('Post').count
    assert_equal 1, Trakable::Trak.for_item_type('Comment').count
  end

  def test_for_event
    post = Post.create!(title: 'T', body: 'B')
    post.update!(title: 'T2')

    assert_equal 1, Trakable::Trak.for_event(:create).count
    assert_equal 1, Trakable::Trak.for_event(:update).count
  end

  def test_for_whodunnit
    user = User.create!(name: 'Alice')
    Trakable::Context.whodunnit = user
    Post.create!(title: 'T', body: 'B')
    Trakable::Context.whodunnit = nil
    Post.create!(title: 'T2', body: 'B2')

    assert_equal 1, Trakable::Trak.for_whodunnit(user).count
  end

  def test_created_before_and_after
    Post.create!(title: 'T', body: 'B')
    # All traks created "now"
    assert_equal 1, Trakable::Trak.created_after(1.hour.ago).count
    assert_equal 1, Trakable::Trak.created_before(1.hour.from_now).count
    assert_equal 0, Trakable::Trak.created_after(1.hour.from_now).count
  end

  def test_recent_orders_by_created_at_desc
    post = Post.create!(title: 'T', body: 'B')
    post.update!(title: 'T2')

    first = Trakable::Trak.recent.first
    assert_equal 'update', first.event
  end

  def test_chained_scopes
    user = User.create!(name: 'X')
    Trakable::Context.whodunnit = user
    post = Post.create!(title: 'T', body: 'B')
    post.update!(title: 'T2')
    Trakable::Context.whodunnit = nil

    result = Trakable::Trak
             .for_item_type('Post')
             .for_event(:update)
             .for_whodunnit(user)
             .created_after(1.hour.ago)
             .recent

    assert_equal 1, result.count
  end
end

# ============================================================
# 8. Reify
# ============================================================
class ReifyTest < IntegrationTest
  def test_reify_returns_nil_for_create
    post = Post.create!(title: 'T', body: 'B')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'create').last
    assert_nil trak.reify
  end

  def test_reify_restores_previous_state_for_update
    post = Post.create!(title: 'V1', body: 'B')
    post.update!(title: 'V2')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'update').last
    reified = trak.reify

    assert_instance_of Post, reified
    assert_equal 'V1', reified.title
    assert_equal 'B', reified.body
    refute reified.persisted?
  end

  def test_reify_restores_state_for_destroy
    post = Post.create!(title: 'Dead', body: 'Gone')
    post_id = post.id
    post.destroy!

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post_id, event: 'destroy').last
    reified = trak.reify

    assert_instance_of Post, reified
    assert_equal 'Dead', reified.title
    refute reified.persisted?
  end

  def test_reify_returns_nil_for_update_when_record_deleted
    post = Post.create!(title: 'V1', body: 'B')
    post.update!(title: 'V2')
    post_id = post.id

    # Force-delete the post without triggering callbacks
    Post.where(id: post_id).delete_all

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post_id, event: 'update').last
    assert_nil trak.reify
  end
end

# ============================================================
# 9. Revert
# ============================================================
class RevertTest < IntegrationTest
  def test_revert_update_restores_previous_values
    post = Post.create!(title: 'Original', body: 'Body')
    post.update!(title: 'Changed')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'update').last
    trak.revert!
    post.reload

    assert_equal 'Original', post.title
  end

  def test_revert_create_destroys_record
    post = Post.create!(title: 'Oops', body: 'B')
    post_id = post.id

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post_id, event: 'create').last
    trak.revert!

    assert_nil Post.find_by(id: post_id)
  end

  def test_revert_destroy_recreates_record
    post = Post.create!(title: 'Comeback', body: 'B')
    post_id = post.id
    post.destroy!

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post_id, event: 'destroy').last
    restored = trak.revert!

    assert_instance_of Post, restored
    assert restored.persisted?
    assert_equal 'Comeback', restored.title
    # New ID (original row is gone)
    refute_equal post_id, restored.id
  end

  def test_revert_with_trak_revert_option
    post = Post.create!(title: 'V1', body: 'B')
    post.update!(title: 'V2')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'update').last
    trak.revert!(trak_revert: true)
    post.reload

    assert_equal 'V1', post.title
    # A "revert" trak should have been created
    revert_trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'revert').last
    assert revert_trak
  end

  def test_revert_update_returns_false_when_record_gone
    post = Post.create!(title: 'V1', body: 'B')
    post.update!(title: 'V2')
    Post.where(id: post.id).delete_all

    trak = Trakable::Trak.where(item_type: 'Post', event: 'update').last
    result = trak.revert!

    refute result
  end
end

# ============================================================
# 10. trak_at (time travel)
# ============================================================
class TrakAtTest < IntegrationTest
  def test_trak_at_returns_state_at_timestamp
    post = Post.create!(title: 'V1', body: 'B')
    sleep 0.05
    t1 = Time.now
    sleep 0.05
    post.update!(title: 'V2')
    sleep 0.05
    post.update!(title: 'V3')

    snapshot = post.trak_at(t1)

    assert_instance_of Post, snapshot
    # At t1 only the create trak exists, which reify returns nil for,
    # so trak_at falls back to dup of current state
  end

  def test_trak_at_returns_nil_before_creation
    post = Post.create!(title: 'T', body: 'B')

    result = post.trak_at(post.created_at - 1.hour)

    assert_nil result
  end

  def test_trak_at_with_no_traks_returns_current_state
    post = Post.create!(title: 'T', body: 'B')
    # Delete all traks to simulate no traks
    Trakable::Trak.delete_all

    result = post.trak_at(Time.now)

    assert_instance_of Post, result
    assert_equal 'T', result.title
  end
end

# ============================================================
# 11. without_tracking / with_tracking
# ============================================================
class TrackingToggleTest < IntegrationTest
  def test_without_tracking_skips_trak_creation
    count_before = Trakable::Trak.count
    Trakable.without_tracking do
      Post.create!(title: 'Ghost', body: 'Invisible')
    end

    assert_equal count_before, Trakable::Trak.count
  end

  def test_with_tracking_inside_without_tracking
    Trakable.without_tracking do
      Trakable.with_tracking do
        Post.create!(title: 'Visible', body: 'Yes')
      end
    end

    assert_equal 1, Trakable::Trak.count
  end

  def test_global_disable_skips_tracking
    Trakable.configuration.enabled = false
    Post.create!(title: 'Nope', body: 'B')

    assert_equal 0, Trakable::Trak.count
  end

  def test_tracking_re_enabled_after_without_tracking
    Trakable.without_tracking do
      Post.create!(title: 'Ghost', body: 'B')
    end

    Post.create!(title: 'Real', body: 'B')
    assert_equal 1, Trakable::Trak.count
  end
end

# ============================================================
# 12. Cleanup: max_traks
# ============================================================
class CleanupMaxTraksTest < IntegrationTest
  def test_max_traks_prunes_oldest
    post = LimitedPost.create!(title: 'V0', body: 'B')
    5.times { |i| post.update!(title: "V#{i + 1}") }

    # 6 traks total (1 create + 5 updates)
    assert_equal 6, Trakable::Trak.where(item_type: 'LimitedPost', item_id: post.id).count

    Trakable::Cleanup.run(post)

    remaining = Trakable::Trak.where(item_type: 'LimitedPost', item_id: post.id)
    assert_equal 3, remaining.count
    # Should keep the 3 most recent
    assert_equal %w[update update update], remaining.order(created_at: :desc).map(&:event)
  end
end

# ============================================================
# 13. Cleanup: retention
# ============================================================
class CleanupRetentionTest < IntegrationTest
  def test_retention_deletes_old_traks
    post = RetainedPost.create!(title: 'T', body: 'B')

    # Backdate traks to 60 days ago
    Trakable::Trak.where(item_type: 'RetainedPost', item_id: post.id)
                  .update_all(created_at: 60.days.ago)

    # Create a recent trak
    post.update!(title: 'T2')

    deleted = Trakable::Cleanup.run_retention(RetainedPost)

    assert_equal 1, deleted
    remaining = Trakable::Trak.where(item_type: 'RetainedPost', item_id: post.id)
    assert_equal 1, remaining.count
    assert_equal 'update', remaining.first.event
  end

  def test_retention_returns_nil_when_not_configured
    result = Trakable::Cleanup.run_retention(Post)

    assert_nil result
  end
end

# ============================================================
# 14. Context isolation (thread safety tested in context_test.rb)
# ============================================================
class ContextIsolationTest < IntegrationTest
  def test_whodunnit_set_and_cleared_around_operations
    user = User.create!(name: 'A')

    Trakable.with_user(user) do
      Post.create!(title: 'Inside', body: 'B')
      assert_equal user, Trakable::Context.whodunnit
    end

    assert_nil Trakable::Context.whodunnit
    Post.create!(title: 'Outside', body: 'B')

    inside_trak = Trakable::Trak.where(item_type: 'Post').order(:id).first
    outside_trak = Trakable::Trak.where(item_type: 'Post').order(:id).last

    assert_equal user.id, inside_trak.whodunnit_id
    assert_nil outside_trak.whodunnit_id
  end

  def test_nested_with_user_blocks
    user_a = User.create!(name: 'A')
    user_b = User.create!(name: 'B')

    Trakable.with_user(user_a) do
      Post.create!(title: 'ByA', body: 'B')

      Trakable.with_user(user_b) do
        Post.create!(title: 'ByB', body: 'B')
      end

      # Back to user_a
      Post.create!(title: 'ByA2', body: 'B')
    end

    traks = Trakable::Trak.where(item_type: 'Post').order(:id)
    assert_equal user_a.id, traks[0].whodunnit_id
    assert_equal user_b.id, traks[1].whodunnit_id
    assert_equal user_a.id, traks[2].whodunnit_id
  end
end

# ============================================================
# 15. Edge cases
# ============================================================
class EdgeCaseTest < IntegrationTest
  def test_update_with_same_value_creates_no_trak
    post = Post.create!(title: 'Same', body: 'B')
    count_before = Trakable::Trak.count

    # ActiveRecord won't register a change if value is identical
    post.update!(title: 'Same')

    assert_equal count_before, Trakable::Trak.count
  end

  def test_nil_to_value_tracked_in_changeset
    post = Post.create!(title: nil, body: nil)
    post.update!(title: 'Now set')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'update').last
    assert_equal [nil, 'Now set'], trak.changeset['title']
  end

  def test_value_to_nil_tracked_in_changeset
    post = Post.create!(title: 'Was set', body: 'B')
    post.update!(title: nil)

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'update').last
    assert_equal ['Was set', nil], trak.changeset['title']
  end

  def test_large_text_stored_correctly
    big_body = 'x' * 100_000
    post = Post.create!(title: 'Big', body: big_body)

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'create').last
    assert_equal big_body, trak.changeset['body'].last
  end

  def test_special_characters_in_values
    post = Post.create!(title: "Test\n\"quotes\" & <tags> 'apos'", body: 'B')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'create').last
    assert_equal "Test\n\"quotes\" & <tags> 'apos'", trak.changeset['title'].last
  end

  def test_unicode_in_values
    post = Post.create!(title: 'Héllo Wörld', body: 'B')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'create').last
    assert_equal 'Héllo Wörld', trak.changeset['title'].last
  end

  def test_emoji_in_values
    post = Post.create!(title: 'Test', body: 'B')

    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'create').last
    assert trak
  end

  def test_multiple_models_tracked_independently
    post = Post.create!(title: 'P', body: 'B')
    Comment.create!(post_id: post.id, content: 'C')

    post_traks = Trakable::Trak.where(item_type: 'Post')
    comment_traks = Trakable::Trak.where(item_type: 'Comment')

    assert_equal 1, post_traks.count
    assert_equal 1, comment_traks.count
  end

  def test_rapid_create_update_destroy_cycle
    100.times do
      p = Post.create!(title: 'T', body: 'B')
      p.update!(title: 'T2')
      p.destroy!
    end

    assert_equal 300, Trakable::Trak.where(item_type: 'Post').count
  end

  def test_item_association_works
    post = Post.create!(title: 'T', body: 'B')
    trak = Trakable::Trak.where(item_type: 'Post', item_id: post.id).last

    assert_equal post, trak.item
  end

  def test_item_returns_nil_when_record_deleted
    post = Post.create!(title: 'T', body: 'B')
    trak_id = Trakable::Trak.where(item_type: 'Post', item_id: post.id, event: 'create').last.id
    Post.where(id: post.id).delete_all

    trak = Trakable::Trak.find(trak_id)
    assert_nil trak.item
  end

  def test_traks_association_on_model
    post = Post.create!(title: 'T', body: 'B')
    post.update!(title: 'T2')

    assert_equal 2, post.traks.count
    assert(post.traks.all?(Trakable::Trak))
  end
end

# ============================================================
# 16. JSON serialization round-trip
# ============================================================
class SerializationTest < IntegrationTest
  def test_changeset_survives_round_trip
    post = Post.create!(title: 'T', body: 'B')
    post.update!(title: 'T2', status: 1)

    trak = Trakable::Trak.find(Trakable::Trak.last.id) # force reload from DB
    assert_equal({ 'title' => ['T', 'T2'], 'status' => [0, 1] }, trak.changeset)
  end

  def test_object_survives_round_trip
    post = Post.create!(title: 'T', body: 'B')
    post.update!(title: 'T2')

    trak = Trakable::Trak.find(Trakable::Trak.last.id)
    assert_equal 'T', trak.object['title']
  end

  def test_metadata_survives_round_trip
    Trakable::Context.metadata = { 'nested' => { 'a' => 1 }, 'arr' => [1, 2, 3] }
    Post.create!(title: 'T', body: 'B')

    trak = Trakable::Trak.find(Trakable::Trak.last.id)
    assert_equal({ 'a' => 1 }, trak.metadata['nested'])
    assert_equal [1, 2, 3], trak.metadata['arr']
  end
end
