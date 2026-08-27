# Household-level numbers for the dashboard: net worth, portfolio MoM change,
# and whether it's time for the monthly value check-in.
class Portfolio
  def initialize(accounts)
    @products = Products.wrap_all(accounts)
  end

  # Sum of signed current amounts across trackable products.
  # Credit cards are excluded; missing amounts count as zero.
  def net_worth
    trackable_products.sum(&:net_worth_contribution)
  end

  # Month-over-month change of portfolio totals for the current vs prior calendar
  # month (by recorded_on). Returns nil when either month has no snapshots or
  # the prior total is zero.
  def monthly_change
    this_month = Date.current.beginning_of_month
    prior_month = this_month.prev_month

    return nil unless any_value_on?(this_month)
    return nil unless any_value_on?(prior_month)

    current_total = total_as_of(this_month)
    prior_total = total_as_of(prior_month)
    MonthlyChange.from_amounts(current_total, prior_total)
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
    trackable_products.sum { |product| product.signed_amount_on(date) }
  end
end
