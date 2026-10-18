class Store < ApplicationRecord
    has_many :tracking_events
    has_many :alerts
end
