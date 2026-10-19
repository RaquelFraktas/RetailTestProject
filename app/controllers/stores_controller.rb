class StoresController < ApplicationController
  def index
    @pagy, @stores = pagy(Store.all.order(:address), limit: 30)
  end

  def show
    @store = Store.find(params[:id])
    @pagy, @tracking_events = pagy(@store.tracking_events
                                          .includes(product: :brand)
                                          .order(event_time: :desc),
                                  limit: 30)
  end
end
