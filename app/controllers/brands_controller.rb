class BrandsController < ApplicationController
  def index
    @pagy, @brands = pagy(Brand.includes(:products).order(:name), limit: 30)
  end

  def show
    @brand = Brand.find(params[:id])
    @pagy, @products = pagy(@brand.products, limit: 30)
  end
end
