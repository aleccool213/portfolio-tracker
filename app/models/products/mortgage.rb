module Products
  # A liability with rate, term, and original principal. The app has only
  # this liability subtype today; a future HELOC would live alongside it.
  class Mortgage < Liability
    # Formatted "4.89% · 5 yr term" line for the dashboard card, or nil.
    def rate_line
      return nil if record.interest_rate.blank?

      line = ActiveSupport::NumberHelper.number_to_percentage(record.interest_rate, precision: 2)
      line += " · #{record.term_months / 12} yr term" if record.term_months.present?
      line
    end
  end
end
