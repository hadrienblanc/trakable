# frozen_string_literal: true

class CreateTraks < ActiveRecord::Migration[7.1]
  def change
    create_table :traks do |t|
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
  end
end
