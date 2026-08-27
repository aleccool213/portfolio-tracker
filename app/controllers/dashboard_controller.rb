class DashboardController < ApplicationController
  # Wrap the account rows once; everything below is kind-blind from here.
  def index
    @products = Products.wrap_all(Account.includes(:account_values).order(:kind, :name))
    @portfolio = Portfolio.new(@products)
    @allocation = Allocation.new(@products)
    @suggestions = AccountSuggestion.for(@products)
    @value_products, @cards = @products.partition(&:trackable?)
  end
end
