class TrackingEvent < ApplicationRecord
    belongs_to :product
    belongs_to :store

    # An event records an inventory check, a price check, or both.
    # A nil inventory_present / price means that check wasn't performed.
    scope :inventory_checks, -> { where.not(inventory_present: nil) }
    scope :price_checks, -> { where.not(price: nil) }

    validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :inventory_or_price_checked

    after_commit :detect_out_of_stock_alerts, on: [:create, :update],
                 if: -> { saved_change_to_inventory_present? || saved_change_to_event_time? }
    # Block form: Rails keeps only the last after_commit registered per method name
    after_destroy_commit { detect_out_of_stock_alerts }

    def inventory_checked?
      !inventory_present.nil?
    end

    def price_checked?
      !price.nil?
    end

    private

    def inventory_or_price_checked
      return if inventory_checked? || price_checked?

      errors.add(:base, "must include an inventory check or a price check")
    end

    # Events can arrive out of order (e.g. from the CSV), so recheck the whole
    # store/product history rather than just the previous event
    def detect_out_of_stock_alerts
      Alerts::OutOfStockDetector.new(store_id: store_id, product_id: product_id).call
    end
end
