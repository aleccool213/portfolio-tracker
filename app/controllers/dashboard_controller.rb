class DashboardController < ApplicationController
  def index
    @accounts = Account.includes(:account_values).order(:kind, :name)
    @portfolio = Portfolio.new(@accounts)
  end
end
