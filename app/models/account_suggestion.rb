# Lightweight Canadian registered-account hints for products you don't hold yet.
# Hard-coded 2026 room notes — clearly dated, not tax advice.
#
# Takes products (see Products.wrap_all): only asset sleeves count as "held",
# so a mortgage or a credit card never suppresses a suggestion.
class AccountSuggestion
  Suggestion = Data.define(:kind, :label, :who_for, :room_note)

  CATALOG = [
    Suggestion.new(
      kind: "tfsa",
      label: "TFSA",
      who_for: "Flexible investing with tax-free growth and withdrawals.",
      room_note: "2026 annual limit is commonly cited around $7,000 (lifetime room is cumulative)."
    ),
    Suggestion.new(
      kind: "rrsp",
      label: "RRSP",
      who_for: "Retirement savings with a tax deduction when you contribute.",
      room_note: "2026 contribution room is generally 18% of prior-year earned income, up to the annual max."
    ),
    Suggestion.new(
      kind: "fhsa",
      label: "FHSA",
      who_for: "First-home savers who want deductible contributions and tax-free withdrawal for a home.",
      room_note: "2026: up to $8,000/year, $40,000 lifetime (confirm CRA figures for your situation)."
    ),
    Suggestion.new(
      kind: "resp",
      label: "RESP",
      who_for: "Education savings with CESG top-ups for kids (or a family plan).",
      room_note: "2026 CESG basics: 20% on the first $2,500 contributed per year, with carry-forward rules."
    )
  ].freeze

  def self.for(products)
    held = Array(products).select(&:asset?).map(&:kind).to_set
    CATALOG.reject { |s| held.include?(s.kind) }
  end
end
