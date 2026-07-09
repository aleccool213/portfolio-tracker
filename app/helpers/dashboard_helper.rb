module DashboardHelper
  # A friendly emoji per account kind, used for the little card icons.
  KIND_EMOJI = {
    "tfsa" => "🌱",
    "rrsp" => "🏦",
    "resp" => "🎓",
    "fhsa" => "🏠",
    "non_registered" => "📈",
    "crypto" => "🪙",
    "cash" => "💵",
    "liability" => "🏡",
    "credit_card" => "💳"
  }.freeze

  def kind_emoji(kind)
    KIND_EMOJI.fetch(kind, "💰")
  end

  # A whole-dollar amount for a card, e.g. 12345.67 => "$12,346".
  # Shows an em dash when no value has been recorded yet.
  def formatted_amount(amount)
    return "—" if amount.nil?

    number_to_currency(amount, unit: "$", precision: 0)
  end
end
