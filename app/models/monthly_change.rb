# Month-over-month % change for an account, based on its two most recent
# AccountValue snapshots. Returns nil when a comparison isn't possible
# (fewer than two values, or a zero prior amount).
class MonthlyChange
  Result = Data.define(:pct, :direction)

  def self.for(account)
    values = account.account_values.order(recorded_on: :desc).limit(2).to_a
    return nil if values.size < 2

    current, prior = values
    return nil if prior.amount.zero?

    # prior.abs keeps liability balances (stored negative) from flipping the
    # sign of the percentage when the debt is paid down or grows.
    pct = ((current.amount - prior.amount) / prior.amount.abs * 100).round(1)

    direction =
      if pct.positive?
        :up
      elsif pct.negative?
        :down
      else
        :flat
      end

    Result.new(pct: pct, direction: direction)
  end
end
