class StoresController < ApplicationController
  def index
    @pagy, @stores = pagy(Store.all, limit: 30)
  end

  def show
    @store = Store.find(params[:id])
    tracking_events = @store.tracking_events.includes(product: :brand).order(created_at: :desc)
    @pagy, @tracking_events = pagy(@store.tracking_events
                                          .includes(product: :brand)
                                          .order(created_at: :desc),
                                  limit: 30)
  end
end
