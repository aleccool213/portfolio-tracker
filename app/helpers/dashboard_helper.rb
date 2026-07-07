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
end
