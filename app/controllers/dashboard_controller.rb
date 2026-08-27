class DashboardController < ApplicationController
  def index
    @accounts = Account.includes(:account_values).order(:kind, :name)
    products = Products.wrap_all(@accounts)
    @portfolio = Portfolio.new(@accounts)
    @allocation = Allocation.new(@accounts)
    @suggestions = AccountSuggestion.for(@accounts)
    @value_products, @cards = products.partition(&:trackable?)
  end
end
