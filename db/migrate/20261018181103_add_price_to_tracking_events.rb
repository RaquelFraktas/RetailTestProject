class AddPriceToTrackingEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :tracking_events, :price, :decimal, precision: 10, scale: 2
  end
end
