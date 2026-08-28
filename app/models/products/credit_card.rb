module Products
  # Perks, annual fee and renewal date — no balance. Cards stay out of net
  # worth, allocation and the monthly check-in.
  class CreditCard < Base
    delegate :annual_fee, :perks, :renewal_on, to: :record

    def trackable?
      false
    end

    def current_amount
      nil
    end

    def amount_on(_date)
      nil
    end

    def chronological_amounts
      []
    end

    def monthly_change
      nil
    end

    def record_amount(_month, _amount)
      raise NotTrackable, "#{name} is a credit card — we track perks, not balances"
    end

    def annual_fee?
      annual_fee.present?
    end

    def renewal?
      renewal_on.present?
    end
  end
end
