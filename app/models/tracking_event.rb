class TrackingEvent < ApplicationRecord
    belongs_to :product
    belongs_to :store

    # An event records an inventory check, a price check, or both.
    # A nil inventory_present / price means that check wasn't performed.
    scope :inventory_checks, -> { where.not(inventory_present: nil) }
    scope :price_checks, -> { where.not(price: nil) }

    validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :inventory_or_price_checked

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
end
