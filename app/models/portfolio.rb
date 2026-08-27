# Household-level numbers for the dashboard: net worth, portfolio MoM change,
# and whether it's time for the monthly value check-in.
#
# Takes products (see Products.wrap_all), not raw Account rows — each product
# knows its own sign and whether it's tracked at all.
class Portfolio
  def initialize(products)
    @products = Array(products)
  end

  # Sum of signed current amounts. Credit cards contribute nothing, and a
  # missing amount counts as zero.
  def net_worth
    @products.sum(&:net_worth_contribution)
  end

  # Month-over-month change of portfolio totals for the current vs prior calendar
  # month (by recorded_on). Returns nil when either month has no snapshots or
  # the prior total is zero.
  def monthly_change
    this_month = Date.current.beginning_of_month
    prior_month = this_month.prev_month

    return nil unless any_value_on?(this_month)
    return nil unless any_value_on?(prior_month)

    MonthlyChange.from_amounts(total_as_of(this_month), total_as_of(prior_month))
  end

  # True when any trackable product is missing a snapshot for this month.
  def needs_check_in?
    month = Date.current.beginning_of_month
    trackable_products.any? { |product| product.amount_on(month).nil? }
  end

  private

  def trackable_products
    @trackable_products ||= @products.select(&:trackable?)
  end

  def any_value_on?(date)
    trackable_products.any? { |product| !product.amount_on(date).nil? }
  end

  def total_as_of(date)
    @products.sum { |product| product.net_worth_contribution_on(date) }
  end
end
