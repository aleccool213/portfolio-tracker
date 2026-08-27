module Products
  # A product with monthly AccountValue snapshots. Assets and liabilities are
  # valued; credit cards are not, so they wrap Base directly.
  class ValuedProduct < Base
    def trackable?
      true
    end

    def current_amount
      record.current_amount
    end

    def amount_on(date)
      values = record.account_values
      if values.loaded?
        values.find { |value| value.recorded_on == date }&.amount
      else
        values.find_by(recorded_on: date)&.amount
      end
    end

    # Upsert this month's snapshot. Shared by the value-entry form and CSV import.
    def record_amount(month, amount)
      value = record.account_values.find_or_initialize_by(recorded_on: month)
      value.update!(amount: amount)
    end

    def net_worth_contribution
      signed_amount(current_amount)
    end

    def signed_amount_on(date)
      signed_amount(amount_on(date))
    end

    def monthly_change
      MonthlyChange.for(record)
    end

    private

    def signed_amount(amount)
      amount.nil? ? 0 : amount
    end
  end
end
