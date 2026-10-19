require "test_helper"

class Alerts::OutOfStockDetectorTest < ActiveSupport::TestCase
  setup do
    @product = products(:one)
    @store = stores(:one)
    # Start from an empty history for this store/product
    TrackingEvent.where(product: @product, store: @store).delete_all
  end

  def record(date, inventory_present: nil, price: nil, store: @store)
    TrackingEvent.create!(product: @product, store: store, event_time: Date.parse(date),
                          inventory_present: inventory_present, price: price)
  end

  test "alerts the brand on the second consecutive no-inventory event" do
    first = record("2025-01-01", inventory_present: false)
    assert_no_difference("Alert.count") { first }

    second = record("2025-01-02", inventory_present: false)
    alert = Alert.sole
    assert_equal @product.brand, alert.brand
    assert_equal @store, alert.store
    assert_equal @product, alert.product
    assert_equal second, alert.tracking_event
    assert_equal first, alert.previous_tracking_event
  end

  test "an in-stock event between them breaks the streak" do
    record("2025-01-01", inventory_present: false)
    record("2025-01-02", inventory_present: true)
    record("2025-01-03", inventory_present: false)
    assert_equal 0, Alert.count
  end

  test "price-only events do not break the streak" do
    record("2025-01-01", inventory_present: false)
    record("2025-01-02", price: 4.99)
    record("2025-01-03", inventory_present: false)
    assert_equal 1, Alert.count
  end

  test "raises one alert per streak, and a new one after a restock" do
    record("2025-01-01", inventory_present: false)
    record("2025-01-02", inventory_present: false)
    record("2025-01-03", inventory_present: false)
    assert_equal 1, Alert.count

    record("2025-01-04", inventory_present: true)
    record("2025-01-05", inventory_present: false)
    record("2025-01-06", inventory_present: false)
    assert_equal 2, Alert.count
  end

  test "orders by event_time, not by when events were recorded" do
    record("2025-01-03", inventory_present: false)
    record("2025-01-01", inventory_present: true)
    record("2025-01-02", inventory_present: false)
    assert_equal Date.parse("2025-01-03"), Alert.sole.tracking_event.event_time.to_date
  end

  test "removes an alert when a late in-stock event lands between the two" do
    record("2025-01-01", inventory_present: false)
    record("2025-01-03", inventory_present: false)
    assert_equal 1, Alert.count

    record("2025-01-02", inventory_present: true)
    assert_equal 0, Alert.count
  end

  test "rechecks the history when an event is deleted" do
    record("2025-01-01", inventory_present: false)
    restock = record("2025-01-02", inventory_present: true)
    record("2025-01-03", inventory_present: false)
    assert_equal 0, Alert.count

    restock.destroy
    assert_equal 1, Alert.count
  end

  test "updating an event rechecks the history" do
    record("2025-01-01", inventory_present: false)
    second = record("2025-01-02", inventory_present: true)

    second.update!(inventory_present: false)
    assert_equal 1, Alert.count
  end

  test "different stores are tracked separately" do
    record("2025-01-01", inventory_present: false)
    record("2025-01-02", inventory_present: false, store: stores(:two))
    assert_equal 0, Alert.count
  end

  test "re-running does not duplicate alerts" do
    record("2025-01-01", inventory_present: false)
    record("2025-01-02", inventory_present: false)

    assert_no_difference("Alert.count") { Alerts::OutOfStockDetector.new.call }
  end
end
