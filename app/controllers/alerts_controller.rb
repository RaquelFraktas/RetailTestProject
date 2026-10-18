class AlertsController < ApplicationController
  def index
    @brand = Brand.find(params[:brand_id]) if params[:brand_id].present?

    alerts = @brand ? @brand.alerts : Alert.all
    @pagy, @alerts = pagy(alerts.order(created_at: :desc)
                                .includes(:brand, :product, :store, :tracking_event, :previous_tracking_event),
                          limit: 30)
  end

  def show
    @alert = Alert.find(params[:id])
  end
end
