require "csv"

module TrackingEvents
  class CsvImporter
    BATCH_SIZE = 1_000

    def initialize(path)
      @path = path
    end

    def call
      row_count = 0
      created_count = 0

      CSV.foreach(@path, headers: true).each_slice(BATCH_SIZE) do |rows|
        row_count += rows.size
        created_count += import_batch(rows)
      end

      Alerts::OutOfStockDetector.new.call
      Rails.logger.info "[TrackingEvents::CsvImporter] rows processed=#{row_count} " \
                        "created=#{created_count} skipped=#{row_count - created_count}"
    end

    private

    def import_batch(rows)
      events = rows.filter_map { |row| build_event(row) }
      TrackingEvent.insert_all(events) if events.any?

      events.size
    end

    def build_event(row)
      store_id   = store_ids[row["Address"]]
      product_id = product_ids[row["Product Name"]]

      # If there's bad data, just skip it (or you could log it)
      return unless store_id && product_id

      inventory_present = cast_boolean(row["Inventory Present"])
      price             = cast_price(row["Price"])

      # insert_all skips validations, so check TrackingEvent's rules here
      return if inventory_present.nil? && price.nil?
      return if price&.negative?

      {
        store_id: store_id,
        product_id: product_id,
        event_time: Date.parse(row["Date"]),
        inventory_present: inventory_present,
        price: price
      }
    end

    # Looked up once, instead of two queries per row
    def store_ids
      @store_ids ||= Store.pluck(:address, :id).to_h
    end

    def product_ids
      @product_ids ||= Product.pluck(:name, :id).to_h
    end

    # Blank means the inventory check wasn't performed
    def cast_boolean(value)
      return nil if value.blank?

      case value
      when true, "true", "TRUE", "t", "T", "1", "True" then true
      else false
      end
    end

    # Blank means the price check wasn't performed; tolerates "$4.99"
    def cast_price(value)
      return nil if value.blank?

      BigDecimal(value.to_s.delete("$,").strip)
    rescue ArgumentError
      nil
    end
  end
end
