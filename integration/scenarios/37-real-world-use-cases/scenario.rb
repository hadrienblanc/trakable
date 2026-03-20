# frozen_string_literal: true

# Scenario 37: Real-World Use Cases
# Tests realistic tracking scenarios across different domains

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

    def for_type(type)
      storage.select { |t| t.item_type == type }
    end

    def clear
      @storage = []
    end
  end
end

# Simple trak object
class SimpleTrak
  attr_accessor :item_type, :item_id, :event, :object, :changeset, :whodunnit, :metadata, :created_at

  def initialize(attrs = {})
    attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    @created_at ||= Time.now
    @metadata ||= {}
  end
end

# ============================================================================
# 1. Blog System
# ============================================================================

class BlogPost
  attr_accessor :id, :title, :body, :status, :author_id, :view_count, :tag_ids, :traks

  STATUSES = %w[draft published archived].freeze

  def initialize(id:, title:, body:, author_id:, status: 'draft')
    @id = id
    @title = title
    @body = body
    @author_id = author_id
    @status = status
    @view_count = 0
    @tag_ids = []
    @traks = []
  end

  def attributes
    {
      'id' => @id,
      'title' => @title,
      'body' => @body,
      'status' => @status,
      'author_id' => @author_id,
      'view_count' => @view_count,
      'tag_ids' => @tag_ids.dup
    }
  end

  def track_event(event, changeset, whodunnit: nil, metadata: {})
    trak = SimpleTrak.new(
      item_type: 'BlogPost',
      item_id: @id,
      event: event,
      object: attributes,
      changeset: changeset,
      whodunnit: whodunnit,
      metadata: metadata
    )
    @traks << trak
    TrakStore << trak
    trak
  end

  def publish!(whodunnit: nil)
    old_status = @status
    @status = 'published'
    track_event('publish', { 'status' => [old_status, @status] }, whodunnit: whodunnit)
  end

  def unpublish!(whodunnit: nil)
    old_status = @status
    @status = 'draft'
    track_event('unpublish', { 'status' => [old_status, @status] }, whodunnit: whodunnit)
  end

  def update!(attrs, whodunnit: nil)
    old_attrs = attributes
    attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }

    changeset = {}
    attributes.each do |k, v|
      changeset[k] = [old_attrs[k], v] if old_attrs[k] != v
    end

    track_event('update', changeset, whodunnit: whodunnit) unless changeset.empty?
  end

  def add_tag!(tag_id, whodunnit: nil)
    return if @tag_ids.include?(tag_id)

    old_tags = @tag_ids.dup
    @tag_ids << tag_id
    track_event('add_tag', { 'tag_ids' => [old_tags, @tag_ids.dup] }, whodunnit: whodunnit)
  end

  def remove_tag!(tag_id, whodunnit: nil)
    return unless @tag_ids.include?(tag_id)

    old_tags = @tag_ids.dup
    @tag_ids.delete(tag_id)
    track_event('remove_tag', { 'tag_ids' => [old_tags, @tag_ids.dup] }, whodunnit: whodunnit)
  end

  def record_view!
    @view_count += 1
    # Don't track every view, just increment
  end
end

class BlogComment
  attr_accessor :id, :post_id, :author_id, :content, :status, :traks

  def initialize(id:, post_id:, author_id:, content:)
    @id = id
    @post_id = post_id
    @author_id = author_id
    @content = content
    @status = 'pending'
    @traks = []
  end

  def attributes
    { 'id' => @id, 'post_id' => @post_id, 'author_id' => @author_id, 'content' => @content, 'status' => @status }
  end

  def track_event(event, changeset, whodunnit: nil)
    trak = SimpleTrak.new(
      item_type: 'BlogComment',
      item_id: @id,
      event: event,
      object: attributes,
      changeset: changeset,
      whodunnit: whodunnit
    )
    @traks << trak
    TrakStore << trak
    trak
  end

  def approve!(whodunnit: nil)
    old_status = @status
    @status = 'approved'
    track_event('approve', { 'status' => [old_status, @status] }, whodunnit: whodunnit)
  end

  def reject!(whodunnit: nil)
    old_status = @status
    @status = 'rejected'
    track_event('reject', { 'status' => [old_status, @status] }, whodunnit: whodunnit)
  end
end

# ============================================================================
# 2. CRM System
# ============================================================================

class CrmLead
  attr_accessor :id, :name, :email, :company, :status, :assigned_to, :value, :traks

  STATUS_FLOW = %w[new contacted qualified proposal negotiated converted lost].freeze

  def initialize(id:, name:, email:, company:)
    @id = id
    @name = name
    @email = email
    @company = company
    @status = 'new'
    @assigned_to = nil
    @value = 0
    @traks = []
  end

  def attributes
    { 'id' => @id, 'name' => @name, 'email' => @email, 'company' => @company,
      'status' => @status, 'assigned_to' => @assigned_to, 'value' => @value }
  end

  def track_event(event, changeset, whodunnit: nil)
    trak = SimpleTrak.new(
      item_type: 'CrmLead',
      item_id: @id,
      event: event,
      object: attributes,
      changeset: changeset,
      whodunnit: whodunnit,
      metadata: { 'pipeline_stage' => @status }
    )
    @traks << trak
    TrakStore << trak
    trak
  end

  def transition_status!(new_status, whodunnit: nil)
    return false unless STATUS_FLOW.include?(new_status)

    old_status = @status
    @status = new_status
    track_event('status_change', { 'status' => [old_status, new_status] }, whodunnit: whodunnit)
    true
  end

  def assign_to!(user_id, whodunnit: nil)
    old_assigned = @assigned_to
    @assigned_to = user_id
    track_event('assign', { 'assigned_to' => [old_assigned, user_id] }, whodunnit: whodunnit)
  end

  def set_value!(amount, whodunnit: nil)
    old_value = @value
    @value = amount
    track_event('value_update', { 'value' => [old_value, amount] }, whodunnit: whodunnit)
  end
end

# ============================================================================
# 3. E-commerce Orders
# ============================================================================

class EcomOrder
  attr_accessor :id, :customer_id, :status, :payment_status, :shipping_status,
                :total, :items, :shipping_address, :tracking_number, :traks

  ORDER_STATUSES = %w[pending confirmed processing shipped delivered cancelled].freeze
  PAYMENT_STATUSES = %w[pending paid refunded failed].freeze
  SHIPPING_STATUSES = %w[not_shipped shipped in_transit delivered returned].freeze

  def initialize(id:, customer_id:, items:, total:)
    @id = id
    @customer_id = customer_id
    @items = items
    @total = total
    @status = 'pending'
    @payment_status = 'pending'
    @shipping_status = 'not_shipped'
    @shipping_address = nil
    @tracking_number = nil
    @traks = []
  end

  def attributes
    { 'id' => @id, 'customer_id' => @customer_id, 'status' => @status,
      'payment_status' => @payment_status, 'shipping_status' => @shipping_status,
      'total' => @total, 'items' => @items, 'tracking_number' => @tracking_number }
  end

  def track_event(event, changeset, whodunnit: nil)
    trak = SimpleTrak.new(
      item_type: 'EcomOrder',
      item_id: @id,
      event: event,
      object: attributes,
      changeset: changeset,
      whodunnit: whodunnit
    )
    @traks << trak
    TrakStore << trak
    trak
  end

  def update_order_status!(new_status, whodunnit: nil)
    old_status = @status
    @status = new_status
    track_event('order_status_change', { 'status' => [old_status, new_status] }, whodunnit: whodunnit)
  end

  def mark_paid!(whodunnit: nil)
    old_payment = @payment_status
    @payment_status = 'paid'
    track_event('payment_update', { 'payment_status' => [old_payment, 'paid'] }, whodunnit: whodunnit)
  end

  def ship!(tracking_number, whodunnit: nil)
    old_shipping = @shipping_status
    @shipping_status = 'shipped'
    @tracking_number = tracking_number
    track_event('shipping_update',
                { 'shipping_status' => [old_shipping, 'shipped'], 'tracking_number' => [nil, tracking_number] },
                whodunnit: whodunnit)
  end

  def deliver!(whodunnit: nil)
    old_shipping = @shipping_status
    old_status = @status
    @shipping_status = 'delivered'
    @status = 'delivered'
    track_event('delivery',
                { 'shipping_status' => [old_shipping, 'delivered'], 'status' => [old_status, 'delivered'] },
                whodunnit: whodunnit)
  end
end

# ============================================================================
# 4. Configuration System
# ============================================================================

class AppConfig
  attr_accessor :id, :key, :value, :environment, :updated_by, :traks

  def initialize(id:, key:, value:, environment: 'production')
    @id = id
    @key = key
    @value = value
    @environment = environment
    @updated_by = nil
    @traks = []
  end

  def attributes
    { 'id' => @id, 'key' => @key, 'value' => @value,
      'environment' => @environment, 'updated_by' => @updated_by }
  end

  def track_event(event, changeset, whodunnit: nil)
    trak = SimpleTrak.new(
      item_type: 'AppConfig',
      item_id: @id,
      event: event,
      object: attributes,
      changeset: changeset,
      whodunnit: whodunnit,
      metadata: { 'config_key' => @key, 'environment' => @environment }
    )
    @traks << trak
    TrakStore << trak
    trak
  end

  def update_value!(new_value, whodunnit: nil)
    old_value = @value
    @value = new_value
    @updated_by = whodunnit
    track_event('config_update', { 'value' => [old_value, new_value] }, whodunnit: whodunnit)
  end
end

# ============================================================================
# 5. Document Management
# ============================================================================

class Document
  attr_accessor :id, :name, :content, :version, :status, :locked_by, :approved_by, :traks

  STATUSES = %w[draft pending_review approved rejected archived].freeze

  def initialize(id:, name:, content:)
    @id = id
    @name = name
    @content = content
    @version = 1
    @status = 'draft'
    @locked_by = nil
    @approved_by = nil
    @traks = []
  end

  def attributes
    { 'id' => @id, 'name' => @name, 'content' => @content, 'version' => @version,
      'status' => @status, 'locked_by' => @locked_by, 'approved_by' => @approved_by }
  end

  def track_event(event, changeset, whodunnit: nil)
    trak = SimpleTrak.new(
      item_type: 'Document',
      item_id: @id,
      event: event,
      object: attributes,
      changeset: changeset,
      whodunnit: whodunnit,
      metadata: { 'version' => @version }
    )
    @traks << trak
    TrakStore << trak
    trak
  end

  def lock!(user_id, whodunnit: nil)
    return false if @locked_by && @locked_by != user_id

    old_locked = @locked_by
    @locked_by = user_id
    track_event('lock', { 'locked_by' => [old_locked, user_id] }, whodunnit: whodunnit)
    true
  end

  def unlock!(user_id, whodunnit: nil)
    return false unless @locked_by == user_id

    old_locked = @locked_by
    @locked_by = nil
    track_event('unlock', { 'locked_by' => [old_locked, nil] }, whodunnit: whodunnit)
    true
  end

  def update_content!(new_content, whodunnit: nil)
    return false if @locked_by && @locked_by != whodunnit

    old_content = @content
    old_version = @version
    @content = new_content
    @version += 1
    track_event('content_update',
                { 'content' => [old_content, new_content], 'version' => [old_version, @version] },
                whodunnit: whodunnit)
    true
  end

  def submit_for_approval!(whodunnit: nil)
    old_status = @status
    @status = 'pending_review'
    track_event('submit', { 'status' => [old_status, @status] }, whodunnit: whodunnit)
  end

  def approve!(approver_id, whodunnit: nil)
    old_status = @status
    @status = 'approved'
    @approved_by = approver_id
    track_event('approve',
                { 'status' => [old_status, 'approved'], 'approved_by' => [nil, approver_id] },
                whodunnit: whodunnit)
  end

  def reject!(whodunnit: nil)
    old_status = @status
    @status = 'rejected'
    track_event('reject', { 'status' => [old_status, 'rejected'] }, whodunnit: whodunnit)
  end
end

# ============================================================================
# 6. User Permissions
# ============================================================================

class Permission
  attr_accessor :id, :user_id, :resource_type, :resource_id, :action, :granted, :traks

  ACTIONS = %w[read write admin delete].freeze

  def initialize(id:, user_id:, resource_type:, resource_id:, action:)
    @id = id
    @user_id = user_id
    @resource_type = resource_type
    @resource_id = resource_id
    @action = action
    @granted = false
    @traks = []
  end

  def attributes
    { 'id' => @id, 'user_id' => @user_id, 'resource_type' => @resource_type,
      'resource_id' => @resource_id, 'action' => @action, 'granted' => @granted }
  end

  def track_event(event, changeset, whodunnit: nil)
    trak = SimpleTrak.new(
      item_type: 'Permission',
      item_id: @id,
      event: event,
      object: attributes,
      changeset: changeset,
      whodunnit: whodunnit,
      metadata: { 'resource' => "#{@resource_type}:#{@resource_id}", 'action' => @action }
    )
    @traks << trak
    TrakStore << trak
    trak
  end

  def grant!(whodunnit: nil)
    old_granted = @granted
    @granted = true
    track_event('grant', { 'granted' => [old_granted, true] }, whodunnit: whodunnit)
  end

  def revoke!(whodunnit: nil)
    old_granted = @granted
    @granted = false
    track_event('revoke', { 'granted' => [old_granted, false] }, whodunnit: whodunnit)
  end
end

# ============================================================================
# 7. Inventory System
# ============================================================================

class InventoryItem
  attr_accessor :id, :sku, :name, :quantity, :reorder_threshold, :supplier_id, :price, :traks

  def initialize(id:, sku:, name:, quantity:, reorder_threshold: 10, supplier_id: nil, price: 0)
    @id = id
    @sku = sku
    @name = name
    @quantity = quantity
    @reorder_threshold = reorder_threshold
    @supplier_id = supplier_id
    @price = price
    @traks = []
  end

  def attributes
    { 'id' => @id, 'sku' => @sku, 'name' => @name, 'quantity' => @quantity,
      'reorder_threshold' => @reorder_threshold, 'supplier_id' => @supplier_id, 'price' => @price }
  end

  def track_event(event, changeset, whodunnit: nil)
    trak = SimpleTrak.new(
      item_type: 'InventoryItem',
      item_id: @id,
      event: event,
      object: attributes,
      changeset: changeset,
      whodunnit: whodunnit,
      metadata: { 'sku' => @sku, 'low_stock' => below_threshold? }
    )
    @traks << trak
    TrakStore << trak
    trak
  end

  def below_threshold?
    @quantity < @reorder_threshold
  end

  def adjust_quantity!(delta, whodunnit: nil, reason: nil)
    old_quantity = @quantity
    @quantity += delta
    @quantity = [0, @quantity].max # Can't go negative
    track_event('quantity_adjustment',
                { 'quantity' => [old_quantity, @quantity] },
                whodunnit: whodunnit)
                .tap { |t| t.metadata['reason'] = reason if reason }
  end

  def set_supplier!(supplier_id, whodunnit: nil)
    old_supplier = @supplier_id
    @supplier_id = supplier_id
    track_event('supplier_change', { 'supplier_id' => [old_supplier, supplier_id] }, whodunnit: whodunnit)
  end

  def set_threshold!(new_threshold, whodunnit: nil)
    old_threshold = @reorder_threshold
    @reorder_threshold = new_threshold
    track_event('threshold_change', { 'reorder_threshold' => [old_threshold, new_threshold] }, whodunnit: whodunnit)
  end
end

# ============================================================================
# 8. Support Tickets
# ============================================================================

class SupportTicket
  attr_accessor :id, :subject, :description, :status, :priority, :customer_id,
                :agent_id, :category, :resolution, :traks

  STATUSES = %w[open in_progress waiting_customer resolved closed].freeze
  PRIORITIES = %w[low medium high urgent].freeze

  def initialize(id:, subject:, description:, customer_id:)
    @id = id
    @subject = subject
    @description = description
    @customer_id = customer_id
    @status = 'open'
    @priority = 'medium'
    @agent_id = nil
    @category = 'general'
    @resolution = nil
    @traks = []
  end

  def attributes
    { 'id' => @id, 'subject' => @subject, 'description' => @description,
      'status' => @status, 'priority' => @priority, 'customer_id' => @customer_id,
      'agent_id' => @agent_id, 'category' => @category, 'resolution' => @resolution }
  end

  def track_event(event, changeset, whodunnit: nil)
    trak = SimpleTrak.new(
      item_type: 'SupportTicket',
      item_id: @id,
      event: event,
      object: attributes,
      changeset: changeset,
      whodunnit: whodunnit,
      metadata: { 'status' => @status, 'priority' => @priority }
    )
    @traks << trak
    TrakStore << trak
    trak
  end

  def change_status!(new_status, whodunnit: nil)
    old_status = @status
    @status = new_status
    track_event('status_change', { 'status' => [old_status, new_status] }, whodunnit: whodunnit)
  end

  def change_priority!(new_priority, whodunnit: nil)
    old_priority = @priority
    @priority = new_priority
    track_event('priority_change', { 'priority' => [old_priority, new_priority] }, whodunnit: whodunnit)
  end

  def assign_agent!(agent_id, whodunnit: nil)
    old_agent = @agent_id
    @agent_id = agent_id
    track_event('agent_assignment', { 'agent_id' => [old_agent, agent_id] }, whodunnit: whodunnit)
  end

  def resolve!(resolution, whodunnit: nil)
    old_status = @status
    old_resolution = @resolution
    @status = 'resolved'
    @resolution = resolution
    track_event('resolve',
                { 'status' => [old_status, 'resolved'], 'resolution' => [old_resolution, resolution] },
                whodunnit: whodunnit)
  end

  def close!(whodunnit: nil)
    old_status = @status
    @status = 'closed'
    track_event('close', { 'status' => [old_status, 'closed'] }, whodunnit: whodunnit)
  end
end

# ============================================================================
# Scenario Tests
# ============================================================================

run_scenario 'Real-World Use Cases' do
  # ==========================================================================
  # TEST 1: Blog System - Posts with comments, authors, tags
  # ==========================================================================
  puts '=== TEST 1: Blog System ==='

  TrakStore.clear

  # Create and publish blog post
  post = BlogPost.new(id: 1, title: 'Getting Started', body: 'Hello World', author_id: 1)
  post.track_event('create', post.attributes, whodunnit: 1)

  # Add tags
  post.add_tag!(101, whodunnit: 1)
  post.add_tag!(102, whodunnit: 1)
  post.add_tag!(103, whodunnit: 1)

  # Publish
  post.publish!(whodunnit: 1)

  # Update content
  post.update!({ 'body' => 'Hello World - Updated!' }, whodunnit: 2)

  # Record some views (not tracked)
  50.times { post.record_view! }

  # Unpublish
  post.unpublish!(whodunnit: 1)

  # Remove a tag
  post.remove_tag!(102, whodunnit: 2)

  # Verify tracking
  post_traks = TrakStore.for_item('BlogPost', 1)
  assert_equal 8, post_traks.length # create + 3 tag adds + publish + update + unpublish + tag remove

  # Verify events
  events = post_traks.map(&:event)
  assert_includes events, 'create'
  assert_includes events, 'publish'
  assert_includes events, 'unpublish'
  assert_includes events, 'add_tag'
  assert_includes events, 'remove_tag'

  # Add comments
  comment1 = BlogComment.new(id: 1, post_id: 1, author_id: 10, content: 'Great post!')
  comment1.track_event('create', comment1.attributes, whodunnit: 10)
  comment1.approve!(whodunnit: 1)

  comment2 = BlogComment.new(id: 2, post_id: 1, author_id: 11, content: 'Spam content')
  comment2.track_event('create', comment2.attributes, whodunnit: 11)
  comment2.reject!(whodunnit: 1)

  comment_traks = TrakStore.for_item('BlogComment', 1)
  assert_equal 2, comment_traks.length
  assert_equal 'approved', comment1.status

  puts '   ✓ Blog post create/update/publish/unpublish cycle tracked'
  puts '   ✓ Blog tags add/remove tracked'
  puts '   ✓ Blog comment moderation tracked'

  # ==========================================================================
  # TEST 2: CRM System - Lead pipeline tracking
  # ==========================================================================
  puts '=== TEST 2: CRM System ==='

  TrakStore.clear

  lead = CrmLead.new(id: 1, name: 'Acme Corp', email: 'contact@acme.com', company: 'Acme')
  lead.track_event('create', lead.attributes, whodunnit: 1)

  # Assign to sales rep
  lead.assign_to!(100, whodunnit: 1)

  # Progress through pipeline
  lead.transition_status!('contacted', whodunnit: 100)
  lead.transition_status!('qualified', whodunnit: 100)
  lead.set_value!(50_000, whodunnit: 100)
  lead.transition_status!('proposal', whodunnit: 100)
  lead.set_value!(75_000, whodunnit: 100) # Value increased after negotiation
  lead.transition_status!('negotiated', whodunnit: 100)
  lead.transition_status!('converted', whodunnit: 100)

  lead_traks = TrakStore.for_item('CrmLead', 1)
  assert_equal 9, lead_traks.length

  # Verify status progression
  status_changes = lead_traks.select { |t| t.event == 'status_change' }
  status_values = status_changes.map { |t| t.changeset['status'][1] }
  assert_equal %w[contacted qualified proposal negotiated converted], status_values

  # Verify pipeline stages in metadata
  status_changes.each do |t|
    assert_equal t.changeset['status'][1], t.metadata['pipeline_stage']
  end

  puts '   ✓ Lead status transitions tracked correctly'
  puts '   ✓ Pipeline stage metadata preserved'
  puts '   ✓ Value updates tracked'

  # Fuzzy test: Random lead transitions
  TrakStore.clear
  leads = 5.times.map { |i| CrmLead.new(id: i + 1, name: "Lead #{i}", email: "lead#{i}@test.com", company: "Company #{i}") }

  100.times do
    lead = leads.sample
    event_type = rand(3)

    case event_type
    when 0
      current_idx = CrmLead::STATUS_FLOW.index(lead.status)
      next_status = CrmLead::STATUS_FLOW[current_idx + 1] if current_idx && current_idx < CrmLead::STATUS_FLOW.length - 1
      lead.transition_status!(next_status, whodunnit: rand(1..10)) if next_status
    when 1
      lead.assign_to!(rand(100..110), whodunnit: rand(1..10))
    when 2
      lead.set_value!(rand(10_000..100_000), whodunnit: rand(1..10))
    end
  end

  total_traks = leads.sum { |l| l.traks.length }
  assert total_traks > 50, 'Should have many tracked events'
  puts '   ✓ Fuzzy test: 100 random lead operations tracked'

  # ==========================================================================
  # TEST 3: E-commerce Orders - Status transitions
  # ==========================================================================
  puts '=== TEST 3: E-commerce Orders ==='

  TrakStore.clear

  order = EcomOrder.new(id: 1, customer_id: 500, items: [{ sku: 'PROD-1', qty: 2, price: 25.00 }], total: 50.00)
  order.track_event('create', order.attributes, whodunnit: 500)

  # Confirm order
  order.update_order_status!('confirmed', whodunnit: 500)

  # Mark as paid
  order.mark_paid!(whodunnit: 'payment_system')

  # Process
  order.update_order_status!('processing', whodunnit: 10)

  # Ship
  order.ship!('TRACK-12345', whodunnit: 10)

  # Deliver
  order.deliver!(whodunnit: 10)

  order_traks = TrakStore.for_item('EcomOrder', 1)
  assert_equal 6, order_traks.length

  # Verify final state
  assert_equal 'delivered', order.status
  assert_equal 'paid', order.payment_status
  assert_equal 'delivered', order.shipping_status
  assert_equal 'TRACK-12345', order.tracking_number

  puts '   ✓ Order status transitions tracked'
  puts '   ✓ Payment status changes tracked'
  puts '   ✓ Shipping with tracking number tracked'

  # Fuzzy test: Multiple orders with random states
  TrakStore.clear
  orders = 10.times.map do |i|
    EcomOrder.new(id: i + 1, customer_id: i + 100, items: [], total: rand(10..500))
  end

  200.times do
    order = orders.sample
    action = rand(6)

    case action
    when 0, 1 # Order status transition - more likely
      current_idx = EcomOrder::ORDER_STATUSES.index(order.status)
      next_status = EcomOrder::ORDER_STATUSES[current_idx + 1] if current_idx && current_idx < EcomOrder::ORDER_STATUSES.length - 1
      order.update_order_status!(next_status, whodunnit: rand(1..10)) if next_status
    when 2 # Mark paid if pending
      order.mark_paid!(whodunnit: 'system') if order.payment_status == 'pending'
    when 3 # Ship if not shipped and paid
      if order.shipping_status == 'not_shipped' && order.payment_status == 'paid'
        order.ship!("TRACK-#{rand(10_000..99_999)}", whodunnit: rand(1..10))
      end
    when 4 # Deliver if shipped
      order.deliver!(whodunnit: rand(1..10)) if order.shipping_status == 'shipped'
    when 5 # Reset order for more testing
      order.status = 'pending'
      order.payment_status = 'pending'
      order.shipping_status = 'not_shipped'
    end
  end

  total_order_traks = orders.sum { |o| o.traks.length }
  assert total_order_traks > 50, "Should have many order events tracked, got #{total_order_traks}"
  puts '   ✓ Fuzzy test: 200 random order operations tracked'

  # ==========================================================================
  # TEST 4: Configuration System - Audit trail
  # ==========================================================================
  puts '=== TEST 4: Configuration System ==='

  TrakStore.clear

  configs = [
    AppConfig.new(id: 1, key: 'app.theme', value: 'light', environment: 'production'),
    AppConfig.new(id: 2, key: 'app.max_users', value: '100', environment: 'production'),
    AppConfig.new(id: 3, key: 'email.smtp_host', value: 'smtp.example.com', environment: 'staging')
  ]

  # Initial track
  configs.each { |c| c.track_event('create', c.attributes, whodunnit: 1) }

  # Update configurations
  configs[0].update_value!('dark', whodunnit: 'admin@example.com')
  configs[1].update_value!('500', whodunnit: 'admin@example.com')
  configs[0].update_value!('auto', whodunnit: 'dev@example.com')
  configs[2].update_value!('smtp.staging.com', whodunnit: 'dev@example.com')

  # Verify audit trail
  config1_traks = TrakStore.for_item('AppConfig', 1)
  assert_equal 3, config1_traks.length # create + 2 updates

  # Verify who changed what
  updates = config1_traks.select { |t| t.event == 'config_update' }
  assert_equal 'admin@example.com', updates[0].whodunnit
  assert_equal ['light', 'dark'], updates[0].changeset['value']
  assert_equal 'dev@example.com', updates[1].whodunnit
  assert_equal ['dark', 'auto'], updates[1].changeset['value']

  # Verify metadata contains config key and environment
  config1_traks.each do |t|
    assert_equal 'app.theme', t.metadata['config_key']
    assert_equal 'production', t.metadata['environment']
  end

  puts '   ✓ Config changes tracked with whodunnit'
  puts '   ✓ Config key and environment in metadata'
  puts '   ✓ Full audit trail available'

  # Fuzzy test: Many config changes
  TrakStore.clear
  test_configs = 20.times.map { |i| AppConfig.new(id: i + 1, key: "config.#{i}", value: "val#{i}") }

  150.times do
    config = test_configs.sample
    new_value = "val#{rand(1000)}"
    config.update_value!(new_value, whodunnit: "user#{rand(1..20)}@example.com")
  end

  total_config_traks = test_configs.sum { |c| c.traks.length }
  assert_equal 150, total_config_traks
  puts '   ✓ Fuzzy test: 150 config changes tracked'

  # ==========================================================================
  # TEST 5: Document Management - Versions and approvals
  # ==========================================================================
  puts '=== TEST 5: Document Management ==='

  TrakStore.clear

  doc = Document.new(id: 1, name: 'Q4 Report', content: 'Initial content')
  doc.track_event('create', doc.attributes, whodunnit: 1)

  # Author locks and edits
  doc.lock!(1, whodunnit: 1)
  doc.update_content!('Draft content v1', whodunnit: 1)
  doc.update_content!('Draft content v2', whodunnit: 1)
  doc.unlock!(1, whodunnit: 1)

  # Submit for approval
  doc.submit_for_approval!(whodunnit: 1)

  # Approver locks, reviews, and approves
  doc.lock!(2, whodunnit: 2)
  doc.approve!(2, whodunnit: 2)
  doc.unlock!(2, whodunnit: 2)

  doc_traks = TrakStore.for_item('Document', 1)
  assert_equal 9, doc_traks.length

  # Verify version progression
  version_traks = doc_traks.select { |t| t.event == 'content_update' }
  assert_equal 2, version_traks.length
  assert_equal 3, doc.version

  # Verify approval
  approve_trak = doc_traks.find { |t| t.event == 'approve' }
  assert_equal 2, approve_trak.changeset['approved_by'][1]

  # Verify locked/unlocked states
  lock_events = doc_traks.select { |t| %w[lock unlock].include?(t.event) }
  assert_equal 4, lock_events.length

  puts '   ✓ Document versions tracked'
  puts '   ✓ Lock/unlock by users tracked'
  puts '   ✓ Approval workflow tracked'

  # Fuzzy test: Multiple documents with random operations
  TrakStore.clear
  docs = 5.times.map { |i| Document.new(id: i + 1, name: "Doc #{i}", content: "Content #{i}") }

  100.times do
    doc = docs.sample
    user = rand(1..5)
    action = rand(8)

    case action
    when 0, 1 # Lock - more likely
      doc.lock!(user, whodunnit: user) unless doc.locked_by
    when 2, 3 # Unlock - more likely
      doc.unlock!(user, whodunnit: user) if doc.locked_by == user
    when 4 # Update content
      if !doc.locked_by || doc.locked_by == user
        doc.update_content!("Updated content #{rand(1000)}", whodunnit: user)
      end
    when 5 # Submit for approval
      doc.submit_for_approval!(whodunnit: user) if doc.status == 'draft'
    when 6 # Approve
      doc.approve!(user, whodunnit: user) if doc.status == 'pending_review'
    when 7 # Reset for more testing
      doc.status = 'draft'
      doc.locked_by = nil
      doc.approved_by = nil
    end
  end

  total_doc_traks = docs.sum { |d| d.traks.length }
  assert total_doc_traks > 20, "Should have many document events, got #{total_doc_traks}"
  puts '   ✓ Fuzzy test: 100 random document operations tracked'

  # ==========================================================================
  # TEST 6: User Permissions - Grants and revokes
  # ==========================================================================
  puts '=== TEST 6: User Permissions ==='

  TrakStore.clear

  perm = Permission.new(id: 1, user_id: 100, resource_type: 'Project', resource_id: 5, action: 'write')
  perm.track_event('create', perm.attributes, whodunnit: 1)

  # Grant permission
  perm.grant!(whodunnit: 'admin@example.com')

  # Revoke
  perm.revoke!(whodunnit: 'admin@example.com')

  # Grant again
  perm.grant!(whodunnit: 'superadmin@example.com')

  perm_traks = TrakStore.for_item('Permission', 1)
  assert_equal 4, perm_traks.length # create + 2 grants + 1 revoke

  # Verify grant/revoke sequence
  grant_revoke = perm_traks.select { |t| %w[grant revoke].include?(t.event) }
  assert_equal 'grant', grant_revoke[0].event
  assert_equal 'revoke', grant_revoke[1].event
  assert_equal 'grant', grant_revoke[2].event

  # Verify metadata
  perm_traks.each do |t|
    assert_equal 'Project:5', t.metadata['resource']
    assert_equal 'write', t.metadata['action']
  end

  puts '   ✓ Permission grants tracked'
  puts '   ✓ Permission revokes tracked'
  puts '   ✓ Resource metadata preserved'

  # Fuzzy test: Many permissions
  TrakStore.clear
  resources = %w[Project Document Report Dashboard Settings]
  actions = Permission::ACTIONS
  perms = []

  50.times do |i|
    perm = Permission.new(
      id: i + 1,
      user_id: rand(1..20),
      resource_type: resources.sample,
      resource_id: rand(1..100),
      action: actions.sample
    )
    perms << perm
    perm.track_event('create', perm.attributes, whodunnit: 1)
  end

  200.times do
    perm = perms.sample
    if perm.granted
      perm.revoke!(whodunnit: "admin#{rand(1..5)}")
    else
      perm.grant!(whodunnit: "admin#{rand(1..5)}")
    end
  end

  total_perm_traks = perms.sum { |p| p.traks.length }
  assert_equal 250, total_perm_traks # 50 creates + 200 toggles
  puts '   ✓ Fuzzy test: 200 random permission changes tracked'

  # ==========================================================================
  # TEST 7: Inventory System - Stock levels and thresholds
  # ==========================================================================
  puts '=== TEST 7: Inventory System ==='

  TrakStore.clear

  item = InventoryItem.new(id: 1, sku: 'WIDGET-001', name: 'Widget', quantity: 100, reorder_threshold: 20, price: 9.99)
  item.track_event('create', item.attributes, whodunnit: 1)

  # Sell some items
  item.adjust_quantity!(-30, whodunnit: 'pos_system', reason: 'sale')
  item.adjust_quantity!(-30, whodunnit: 'pos_system', reason: 'sale')
  item.adjust_quantity!(-30, whodunnit: 'pos_system', reason: 'sale')

  # Check if below threshold (100 - 90 = 10, which is below 20)
  assert item.below_threshold?

  # Restock
  item.adjust_quantity!(100, whodunnit: 2, reason: 'restock')

  # Change supplier
  item.set_supplier!(50, whodunnit: 1)

  # Change threshold
  item.set_threshold!(50, whodunnit: 1)

  item_traks = TrakStore.for_item('InventoryItem', 1)
  assert_equal 7, item_traks.length

  # Verify quantity changes
  qty_traks = item_traks.select { |t| t.event == 'quantity_adjustment' }
  assert_equal 4, qty_traks.length

  # Verify quantity tracking (100 - 90 + 100 = 110)
  assert_equal 110, item.quantity

  # Verify low stock metadata
  low_stock_traks = item_traks.select { |t| t.metadata['low_stock'] == true }
  assert low_stock_traks.length > 0, 'Should have low stock events'

  puts '   ✓ Quantity adjustments tracked with reasons'
  puts '   ✓ Supplier changes tracked'
  puts '   ✓ Threshold changes tracked'
  puts '   ✓ Low stock flag in metadata'

  # Fuzzy test: Multiple items with random stock changes
  TrakStore.clear
  items = 10.times.map { |i| InventoryItem.new(id: i + 1, sku: "ITEM-#{i}", name: "Item #{i}", quantity: rand(50..200)) }

  150.times do
    item = items.sample
    action = rand(4)

    case action
    when 0, 1 # Sale (more common)
      delta = -rand(1..20)
      item.adjust_quantity!(delta, whodunnit: 'pos', reason: 'sale')
    when 2 # Restock
      delta = rand(10..50)
      item.adjust_quantity!(delta, whodunnit: rand(1..5), reason: 'restock')
    when 3 # Change threshold/supplier
      if rand(2) == 0
        item.set_threshold!(rand(10..100), whodunnit: rand(1..5))
      else
        item.set_supplier!(rand(1..20), whodunnit: rand(1..5))
      end
    end
  end

  total_item_traks = items.sum { |i| i.traks.length }
  assert total_item_traks > 100, 'Should have many inventory events'
  puts '   ✓ Fuzzy test: 150 random inventory operations tracked'

  # ==========================================================================
  # TEST 8: Support Tickets - Lifecycle and assignments
  # ==========================================================================
  puts '=== TEST 8: Support Tickets ==='

  TrakStore.clear

  ticket = SupportTicket.new(id: 1, subject: 'Cannot login', description: 'I forgot my password', customer_id: 500)
  ticket.track_event('create', ticket.attributes, whodunnit: 500)

  # Escalate priority
  ticket.change_priority!('high', whodunnit: 500)

  # Assign to agent
  ticket.assign_agent!(100, whodunnit: 'system')

  # Agent picks up
  ticket.change_status!('in_progress', whodunnit: 100)

  # Need more info
  ticket.change_status!('waiting_customer', whodunnit: 100)

  # Customer responds
  ticket.change_status!('in_progress', whodunnit: 500)

  # Resolve
  ticket.resolve!('Password reset link sent', whodunnit: 100)

  # Close after confirmation
  ticket.close!(whodunnit: 500)

  ticket_traks = TrakStore.for_item('SupportTicket', 1)
  assert_equal 8, ticket_traks.length

  # Verify status progression - includes status_change, resolve, and close events
  status_traks = ticket_traks.select { |t| %w[status_change resolve close].include?(t.event) }
  status_values = status_traks.map { |t| t.changeset['status'][1] }
  assert_equal %w[in_progress waiting_customer in_progress resolved closed], status_values

  # Verify final state
  assert_equal 'closed', ticket.status
  assert_equal 'high', ticket.priority
  assert_equal 100, ticket.agent_id

  puts '   ✓ Ticket status transitions tracked'
  puts '   ✓ Priority changes tracked'
  puts '   ✓ Agent assignments tracked'
  puts '   ✓ Resolution tracked'

  # Fuzzy test: Multiple tickets with random operations
  TrakStore.clear
  tickets = 15.times.map { |i| SupportTicket.new(id: i + 1, subject: "Issue #{i}", description: "Description #{i}", customer_id: rand(100..200)) }

  200.times do
    ticket = tickets.sample
    action = rand(7)

    case action
    when 0, 1 # Status transition - more likely
      current_idx = SupportTicket::STATUSES.index(ticket.status)
      next_status = SupportTicket::STATUSES[current_idx + 1] if current_idx && current_idx < SupportTicket::STATUSES.length - 1
      ticket.change_status!(next_status, whodunnit: rand(1..50)) if next_status
    when 2, 3 # Priority change - more likely
      ticket.change_priority!(SupportTicket::PRIORITIES.sample, whodunnit: rand(1..50))
    when 4 # Agent assignment
      ticket.assign_agent!(rand(1..10), whodunnit: rand(1..10)) if ticket.agent_id.nil?
    when 5 # Resolve if in progress
      ticket.resolve!("Resolution #{rand(1000)}", whodunnit: ticket.agent_id || rand(1..10)) if ticket.status == 'in_progress'
    when 6 # Reset for more testing
      ticket.status = 'open'
      ticket.agent_id = nil
    end
  end

  total_ticket_traks = tickets.sum { |t| t.traks.length }
  assert total_ticket_traks > 50, "Should have many ticket events, got #{total_ticket_traks}"
  puts '   ✓ Fuzzy test: 200 random ticket operations tracked'

  puts "\n=== Scenario 37: Real-World Use Cases PASSED ==="
end
