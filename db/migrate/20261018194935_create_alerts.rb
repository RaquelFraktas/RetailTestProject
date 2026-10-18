class CreateAlerts < ActiveRecord::Migration[7.1]
  def change
    create_table :alerts do |t|
      t.references :brand, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :store, null: false, foreign_key: true
      # The second consecutive "no inventory" event, which triggered the alert
      t.references :tracking_event, null: false, index: { unique: true },
                   foreign_key: { on_delete: :cascade }
      # The "no inventory" event immediately before it
      t.references :previous_tracking_event, null: false,
                   foreign_key: { to_table: :tracking_events, on_delete: :cascade }

      t.timestamps
    end

    # Out-of-stock detection walks one store/product history in event_time order
    add_index :tracking_events, [:store_id, :product_id, :event_time]
  end
end
