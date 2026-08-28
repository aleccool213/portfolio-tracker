module Products
  # Shared behaviour for every product: identity delegated to the Account row,
  # plus the monthly-snapshot plumbing that valued products share.
  # Products::CreditCard opts out of the value side.
  class Base
    # Narrow escape hatch for persistence (forms, routes, destroy).
    attr_reader :record

    delegate :id, :to_param, :name, :institution, :kind, :kind_label, to: :record

    def initialize(record)
      @record = record
    end

    # --- roles ---------------------------------------------------------------

    # Does this product get a monthly value? (check-in + value entry)
    def trackable?
      true
    end

    # Does it count as an asset? (allocation, registered-account suggestions)
    def asset?
      false
    end

    # Signed contribution to household net worth, from the latest snapshot.
    def net_worth_contribution
      signed(current_amount)
    end

    # ...as of a given month. A month with no snapshot counts as zero.
    def net_worth_contribution_on(date)
      signed(amount_on(date))
    end

    # --- values --------------------------------------------------------------

    def current_amount
      record.current_amount
    end

    def amount_on(date)
      value_on(date)&.amount
    end

    # Upsert this product's snapshot for a month. Shared by the monthly
    # check-in and anything else that records values.
    def record_amount(month, amount)
      value = record.account_values.find_or_initialize_by(recorded_on: month)
      value.update!(amount: amount)
      value
    end

    # Oldest-first amounts, for sparklines.
    def chronological_amounts
      record.account_values.sort_by(&:recorded_on).map(&:amount)
    end

    def monthly_change
      MonthlyChange.for(record)
    end

    # --- presentation --------------------------------------------------------

    # Does this product have a rate/term line to show on its card?
    def rate_line?
      false
    end

    def ==(other)
      other.class == self.class && other.record == record
    end
    alias_method :eql?, :==

    def hash
      [ self.class, record ].hash
    end

    private

    # Assets keep their sign; liabilities flip it. Missing amounts are zero.
    def signed(amount)
      amount || 0
    end

    def value_on(date)
      values = record.account_values
      if values.loaded?
        values.find { |value| value.recorded_on == date }
      else
        values.find_by(recorded_on: date)
      end
    end
  end
end
