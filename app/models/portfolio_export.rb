# Builds format-agnostic PortfolioRows from accounts. A codec (CSV today)
# turns these into a downloadable file.
class PortfolioExport
  # One row per monthly snapshot; credit cards (no values) get a single blank-value row.
  def self.rows(accounts = Account.includes(:account_values).order(:kind, :name))
    Array(accounts).flat_map { |account| rows_for(account) }
  end

  # One PortfolioRow per snapshot; a nil snapshot keeps credit cards in the file.
  def self.rows_for(account)
    values = account.account_values.chronological.to_a
    snapshots = values.empty? ? [ nil ] : values

    snapshots.map do |value|
      PortfolioRow.new(
        account_id: account.id,
        value_id: value&.id,
        name: account.name,
        institution: account.institution,
        kind: account.kind,
        recorded_on: value&.recorded_on,
        amount: value&.amount,
        interest_rate: account.interest_rate,
        term_months: account.term_months,
        original_principal: account.original_principal
      )
    end
  end
  private_class_method :rows_for
end
