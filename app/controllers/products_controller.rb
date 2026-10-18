class ProductsController < ApplicationController
  def index
    @pagy, @products = pagy(Product.includes(:brand), limit: 30)
  end

  def show
    @product = Product.find(params[:id])
    @pagy, @tracking_events = pagy(@product.tracking_events
                                            .includes(:store)
                                            .order(created_at: :desc), 
                                    limit: 30)
  end
end
