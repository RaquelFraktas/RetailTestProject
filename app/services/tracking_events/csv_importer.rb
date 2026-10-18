require "csv"

module TrackingEvents
  class CsvImporter
    def initialize(path)
      @path = path
    end

    def call
      row_count = 0
      created_count = 0

      CSV.foreach(@path, headers: true) do |row|
        row_count += 1

        store   = Store.find_by(address: row["Address"])
        product = Product.find_by(name: row["Product Name"])

        # If there's bad data, just skip it (or you could log it)
        next unless store && product

        event_time       = Date.parse(row["Date"])
        inventory_present = cast_boolean(row["Inventory Present"])
        price            = cast_price(row["Price"])

        # A row with neither check has nothing to record
        next if inventory_present.nil? && price.nil?

        TrackingEvent.create!(
          store: store,
          product: product,
          event_time: event_time,
          inventory_present: inventory_present,
          price: price
        )

        created_count += 1
      end

      Rails.logger.info "[TrackingEvents::CsvImporter] rows processed=#{row_count} created=#{created_count}"
    end

    private

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