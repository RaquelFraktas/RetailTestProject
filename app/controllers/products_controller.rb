class ProductsController < ApplicationController
  def index
    @pagy, @products = pagy(Product.all, limit: 30)
  end

  def show
    @product = Product.find(params[:id])
    @pagy, @tracking_events = pagy(@product.tracking_events, limit: 30)
  end
end
