# One snapshot of an account as seen by import/export. Format codecs
# (CSV today, JSON later) encode and decode this; PortfolioImport /
# PortfolioExport never see the file type.
class PortfolioRow < Data.define(
  :account_id, :value_id, :name, :institution, :kind, :recorded_on, :amount,
  :interest_rate, :term_months, :original_principal, :origin
)
  def initialize(account_id: nil, value_id: nil, name: nil, institution: nil, kind: nil,
                 recorded_on: nil, amount: nil, interest_rate: nil, term_months: nil,
                 original_principal: nil, origin: nil)
    super
  end
end
