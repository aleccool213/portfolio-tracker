class DashboardController < ApplicationController
  def index
    @accounts = Account.includes(:account_values).order(:kind, :name)
    @portfolio = Portfolio.new(@accounts)
    @allocation = Allocation.new(@accounts)
    @suggestions = AccountSuggestion.for(@accounts)
    @cards = @accounts.select(&:credit_card?)
    @value_accounts = @accounts.reject(&:credit_card?)
  end
end
