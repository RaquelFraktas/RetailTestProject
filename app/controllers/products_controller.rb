class ProductsController < ApplicationController
  def index
    @pagy, @products = pagy(Product.includes(:brand).order(:name), limit: 30)
  end

  def show
    @product = Product.find(params[:id])
    @pagy, @tracking_events = pagy(@product.tracking_events
                                           .includes(:store)
                                           .order(event_time: :desc),
                                          limit: 30)
  end
end
