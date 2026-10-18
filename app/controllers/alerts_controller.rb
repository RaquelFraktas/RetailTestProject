class AlertsController < ApplicationController
  PER_PAGE = 100

  def index
    @brand = Brand.find(params[:brand_id]) if params[:brand_id].present?
    @page = [params[:page].to_i, 1].max

    alerts = @brand ? @brand.alerts : Alert.all
    @total = alerts.count
    @alerts = alerts.newest_first
                    .includes(:brand, :product, :store, :tracking_event, :previous_tracking_event)
                    .limit(PER_PAGE)
                    .offset((@page - 1) * PER_PAGE)
  end

  def show
    @alert = Alert.find(params[:id])
  end
end
