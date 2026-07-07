class DashboardController < ApplicationController
  def index
    @accounts = Account.order(:kind, :name)
  end
end
