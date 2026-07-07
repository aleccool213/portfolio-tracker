# Seed data for local dev and for the throwaway cloud test deploys.
#
# Idempotent: safe to run on every boot. We key off (name, institution) so
# re-running never creates duplicates.
#
# This is fictional sample data shaped like a typical Canadian Wealthsimple
# setup, so the dashboard has something to show before the real value-tracking
# features land in later PRs.

sample_accounts = [
  { name: "Managed TFSA",        institution: "Wealthsimple", kind: "tfsa" },
  { name: "Self-directed TFSA",  institution: "Wealthsimple", kind: "tfsa" },
  { name: "RRSP",                institution: "Wealthsimple", kind: "rrsp" },
  { name: "Family RESP",         institution: "Wealthsimple", kind: "resp" },
  { name: "FHSA",                institution: "Wealthsimple", kind: "fhsa" },
  { name: "Crypto",              institution: "Wealthsimple", kind: "crypto" },
  { name: "Everyday chequing",   institution: "Wealthsimple", kind: "cash" },
  { name: "Home mortgage",       institution: "RBC",          kind: "liability" },
  { name: "Aeroplan Visa Infinite", institution: "TD",        kind: "credit_card" }
]

sample_accounts.each do |attrs|
  Account.find_or_create_by!(name: attrs[:name], institution: attrs[:institution]) do |account|
    account.kind = attrs[:kind]
  end
end

puts "Seeded #{Account.count} accounts."
