# Household-level numbers for the dashboard: net worth, portfolio MoM change,
# and whether it's time for the monthly value check-in.
class Portfolio
  def initialize(accounts)
    @accounts = Array(accounts)
  end

  # Sum of signed current amounts across trackable accounts.
  # Credit cards are excluded; missing amounts count as zero.
  def net_worth
    trackable_accounts.sum { |account| signed_amount(account, account.current_amount) }
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

  # True when any trackable account is missing a snapshot for this month.
  def needs_check_in?
    month = Date.current.beginning_of_month
    trackable_accounts.any? { |account| amount_on(account, month).nil? }
  end

  private

  def trackable_accounts
    @trackable_accounts ||= @accounts.reject { |account| account.kind == "credit_card" }
  end

  def signed_amount(account, amount)
    return 0 if amount.nil?

    account.kind == "liability" ? -amount.abs : amount
  end

  def amount_on(account, date)
    values = account.account_values
    if values.loaded?
      values.find { |value| value.recorded_on == date }&.amount
    else
      values.find_by(recorded_on: date)&.amount
    end
  end

  def any_value_on?(date)
    trackable_accounts.any? { |account| !amount_on(account, date).nil? }
  end

  def total_as_of(date)
    trackable_accounts.sum { |account| signed_amount(account, amount_on(account, date)) }
  end
end
