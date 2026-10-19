class Alert < ApplicationRecord
  belongs_to :brand
  belongs_to :product
  belongs_to :store
  belongs_to :tracking_event
  belongs_to :previous_tracking_event, class_name: "TrackingEvent"
end
