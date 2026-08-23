# Seed data for local dev and for the throwaway cloud test deploys.
#
# Idempotent: safe to run on every boot. We key off (name, institution) so
# re-running never creates duplicates.
#
# This is fictional sample data shaped like a typical Canadian Wealthsimple
# setup, so the dashboard has something to show before the real value-tracking
# features land in later PRs.
#
# We deliberately skip FHSA and RESP so "Ideas for Canada" has suggestions
# on a fresh Render preview (the household already has a mortgage / home).

sample_accounts = [
  { name: "Managed TFSA",        institution: "Wealthsimple", kind: "tfsa" },
  { name: "Self-directed TFSA",  institution: "Wealthsimple", kind: "tfsa" },
  { name: "RRSP",                institution: "Wealthsimple", kind: "rrsp" },
  { name: "Crypto",              institution: "Wealthsimple", kind: "crypto" },
  { name: "Everyday chequing",   institution: "Wealthsimple", kind: "cash" },
  { name: "Home mortgage",       institution: "RBC",          kind: "liability",
    interest_rate: 4.89, term_months: 60, original_principal: 450_000 },
  { name: "Aeroplan Visa Infinite", institution: "TD",        kind: "credit_card" },
  { name: "Amex Cobalt",           institution: "Amex",      kind: "credit_card" },
  { name: "Simplii no-fee",        institution: "Simplii",   kind: "credit_card" }
]

sample_accounts.each do |attrs|
  Account.find_or_create_by!(name: attrs[:name], institution: attrs[:institution]) do |account|
    account.assign_attributes(attrs.except(:name, :institution))
  end
end

# Mortgage details for the liability decision view (idempotent update).
mortgage = Account.find_by(name: "Home mortgage", institution: "RBC")
if mortgage
  mortgage.update!(
    kind: "liability",
    interest_rate: 4.89,
    term_months: 60,
    original_principal: 450_000
  )
end

# Credit-card perks (no balances). Idempotent field updates.
card_details = {
  [ "Aeroplan Visa Infinite", "TD" ] => {
    annual_fee: 139,
    perks: "Aeroplan points, first checked bag free, lounge passes.",
    renewal_on: Date.new(Date.current.year, 11, 1)
  },
  [ "Amex Cobalt", "Amex" ] => {
    annual_fee: 12.99 * 12,
    perks: "5x on groceries & transit, solid everyday earner.",
    renewal_on: Date.new(Date.current.year, 3, 15)
  },
  [ "Simplii no-fee", "Simplii" ] => {
    annual_fee: 0,
    perks: "No annual fee backup card for free withdrawals.",
    renewal_on: Date.new(Date.current.year, 8, 1)
  }
}

card_details.each do |(name, institution), details|
  card = Account.find_by(name: name, institution: institution)
  card&.update!(details.merge(kind: "credit_card"))
end

# Monthly snapshots (AccountValue) so the dashboard has real dollar figures.
#
# Six months ending this month, keyed on (account, recorded_on) so re-seeding
# never duplicates. Assets grow gently; the mortgage balance shrinks (and is
# stored as a negative amount, since a liability is money owed). Credit cards
# are intentionally value-less and get no snapshots.
STARTING_AMOUNTS = {
  "Managed TFSA" => 42_000,
  "Self-directed TFSA" => 18_500,
  "RRSP" => 61_000,
  "Crypto" => 3_400,
  "Everyday chequing" => 4_200,
  "Home mortgage" => -318_000
}.freeze

months = (0..5).map { |ago| ago.months.ago.to_date.beginning_of_month }.reverse

Account.where.not(kind: "credit_card").find_each do |account|
  start = STARTING_AMOUNTS[account.name]
  next if start.nil?

  months.each_with_index do |recorded_on, i|
    amount =
      if account.kind == "liability"
        # Pay down ~$900/month against a negative (owed) balance.
        start + (i * 900)
      else
        # Grow ~1.5% per month, compounded.
        (start * (1.015**i)).round(2)
      end

    AccountValue.find_or_create_by!(account: account, recorded_on: recorded_on) do |value|
      value.amount = amount
    end
  end
end

puts "Seeded #{Account.count} accounts and #{AccountValue.count} monthly values."
