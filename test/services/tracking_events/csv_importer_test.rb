require "test_helper"
require "csv"
require "tempfile"

class TrackingEvents::CsvImporterTest < ActiveSupport::TestCase
  setup do
    @store = stores(:one)
    @product = products(:one)
    TrackingEvent.delete_all
  end

  def import(*rows)
    csv = Tempfile.new(["tracking_events", ".csv"])
    csv.write("Address,Product Name,Date,Inventory Present,Price\n")
    rows.each { |row| csv.write(row.to_csv) }
    csv.close

    TrackingEvents::CsvImporter.new(csv.path).call
  ensure
    csv&.unlink
  end

  test "imports inventory and price checks" do
    import(
      [@store.address, @product.name, "2025-01-01", "True", ""],
      [@store.address, @product.name, "2025-01-02", "", "$4.99"]
    )

    inventory, price = TrackingEvent.order(:event_time).to_a
    assert_equal true, inventory.inventory_present
    assert_nil inventory.price
    assert_nil price.inventory_present
    assert_equal BigDecimal("4.99"), price.price
  end

  test "skips unknown stores and products, empty checks and negative prices" do
    import(
      ["Nowhere", @product.name, "2025-01-01", "True", ""],
      [@store.address, "Nothing", "2025-01-01", "True", ""],
      [@store.address, @product.name, "2025-01-01", "", ""],
      [@store.address, @product.name, "2025-01-01", "", "-1"]
    )

    assert_equal 0, TrackingEvent.count
  end

  test "detects out-of-stock alerts" do
    import(
      [@store.address, @product.name, "2025-01-01", "False", ""],
      [@store.address, @product.name, "2025-01-02", "False", ""]
    )

    alert = Alert.sole
    assert_equal @store, alert.store
    assert_equal @product, alert.product
  end
end
