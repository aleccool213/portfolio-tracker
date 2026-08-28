module Products
  # A liability with rate, term and original principal.
  class Mortgage < Liability
    delegate :interest_rate, :term_months, :original_principal, to: :record

    def rate_line?
      interest_rate.present?
    end

    def term_years
      return nil if term_months.blank?

      term_months / 12
    end
  end
end
