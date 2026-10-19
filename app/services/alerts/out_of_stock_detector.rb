module Alerts
  # Creates an Alert for the product's brand when a store records two
  # "no inventory" events in a row for the same product, ordered by event_time.
  #
  # Only inventory checks count: price-only events (inventory_present nil) are
  # skipped, so they neither break nor extend a streak. One alert is raised per
  # streak, on its second event; the next alert needs a restock in between.
  #
  # Re-running is safe: alerts are unique per triggering event. Events can
  # arrive out of order, so alerts the history no longer supports (e.g. a
  # late in-stock event landed between the two) are removed.
  class OutOfStockDetector
    # Pass store_id and product_id to check one history; omit both to check all.
    def initialize(store_id: nil, product_id: nil)
      @store_id = store_id
      @product_id = product_id
    end

    def call
      rows = alert_rows
      tracking_event_ids = rows.map { |row| row[:tracking_event_id] }

      Alert.transaction do
        # Delete stale alerts
        filter_for_store_and_product(Alert.all).where.not(tracking_event_id: tracking_event_ids).delete_all
        # The previous event can change when an earlier event arrives late
        Alert.upsert_all(rows, unique_by: :tracking_event_id, update_only: [:previous_tracking_event_id]) if rows.any?
      end
    end

    private

    def alert_rows
      inventory_histories.flat_map do |history|
        streak = 0
        previous_id = nil

        history.filter_map do |id, store_id, product_id, brand_id, inventory_present|
          streak = inventory_present ? 0 : streak + 1

          if streak == 2
            alert = {
              brand_id: brand_id,
              store_id: store_id,
              product_id: product_id,
              tracking_event_id: id,
              previous_tracking_event_id: previous_id
            }
          end

          previous_id = id
          alert
        end
      end
    end

    # Each store/product's inventory checks, oldest first. Same-day events are
    # ordered by id, i.e. the order they were recorded.
    def inventory_histories
      filter_for_store_and_product(TrackingEvent.inventory_checks)
        .joins(:product)
        .order(:store_id, :product_id, :event_time, :id)
        .pluck("tracking_events.id", :store_id, :product_id, "products.brand_id", :inventory_present)
        .group_by { |_id, store_id, product_id| [store_id, product_id] }
        .values
    end

    # A full run (no store/product given) checks every history
    def filter_for_store_and_product(records)
      return records unless @store_id && @product_id

      records.where(store_id: @store_id, product_id: @product_id)
    end
  end
end
