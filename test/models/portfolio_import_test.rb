require "test_helper"
require "stringio"

class PortfolioImportTest < ActiveSupport::TestCase
  def import_csv(str)
    decoded = PortfolioFormats::Csv.parse(StringIO.new(str))
    return PortfolioImport::Result.new(
      accounts_created: 0, accounts_updated: 0, values_upserted: 0, errors: decoded.errors
    ) if decoded.errors.any?

    PortfolioImport.new(decoded.rows).call
  end

  test "preview does not persist new accounts or values" do
    rows = [
      PortfolioRow.new(name: "Preview TFSA", institution: "Bank", kind: "tfsa",
                       recorded_on: Date.new(2026, 1, 1), amount: 1_000)
    ]

    assert_no_difference [ "Account.count", "AccountValue.count" ] do
      plan = PortfolioImport.new(rows).preview
      assert plan.success?, plan.errors.inspect
      assert_equal :create, plan.entries.first.account_action
      assert_equal :create, plan.entries.first.value_action
    end

    assert_not Account.exists?(name: "Preview TFSA")
  end

  test "preview marks the first month of a new account as create and later months as keep" do
    rows = [
      PortfolioRow.new(name: "New TFSA", institution: "Bank", kind: "tfsa",
                       recorded_on: Date.new(2026, 1, 1), amount: 10, origin: "Line 2"),
      PortfolioRow.new(name: "New TFSA", institution: "Bank", kind: "tfsa",
                       recorded_on: Date.new(2026, 2, 1), amount: 20, origin: "Line 3")
    ]

    plan = PortfolioImport.new(rows).preview

    assert plan.success?, plan.errors.inspect
    assert_equal :create, plan.entries[0].account_action
    assert_equal :create, plan.entries[0].value_action
    assert_equal :keep, plan.entries[1].account_action
    assert_equal :create, plan.entries[1].value_action
    assert_match(/1 account will be created/, plan.summary)
    assert_match(/2 values will be created/, plan.summary)
  end

  test "preview marks a new month on an existing account as create value" do
    account = accounts(:managed_tfsa)
    rows = [
      PortfolioRow.new(name: account.name, institution: account.institution, kind: account.kind,
                       recorded_on: Date.new(2026, 7, 1), amount: 50_000)
    ]

    plan = PortfolioImport.new(rows).preview

    assert plan.success?, plan.errors.inspect
    assert_equal :keep, plan.entries.first.account_action
    assert_equal :create, plan.entries.first.value_action
    assert_match(/1 value will be created/, plan.summary)
  end

  test "preview reports account rename and value amount change with before and after" do
    tfsa = accounts(:managed_tfsa)
    value = account_values(:managed_tfsa_june)

    plan = PortfolioImport.new([
      PortfolioRow.new(
        account_id: tfsa.id, value_id: value.id, name: "Renamed TFSA", institution: tfsa.institution,
        kind: tfsa.kind, recorded_on: value.recorded_on, amount: 99_999
      )
    ]).preview

    assert plan.success?, plan.errors.inspect
    entry = plan.entries.first
    assert_equal :update, entry.account_action
    assert_equal :update, entry.value_action
    assert_equal [ "Managed TFSA", "Renamed TFSA" ], entry.account_changes["name"]
    assert_equal [ BigDecimal("43500"), BigDecimal("99999") ], entry.value_changes["amount"]
    assert_equal "Managed TFSA", tfsa.reload.name
    assert_equal BigDecimal("43500"), value.reload.amount
  end

  test "preview of an export is all keep" do
    tfsa = accounts(:managed_tfsa)
    rows = PortfolioExport.rows([ tfsa ])

    plan = PortfolioImport.new(rows).preview

    assert plan.success?, plan.errors.inspect
    assert plan.entries.any?
    assert plan.entries.all? { |entry| entry.account_action == :keep }
    assert plan.entries.all? { |entry| entry.value_action == :keep }
    assert_equal "Nothing will change", plan.summary
  end

  test "preview rejects a credit card with a balance and does not persist" do
    rows = [
      PortfolioRow.new(name: "Preview Visa", institution: "TD", kind: "credit_card",
                       recorded_on: Date.new(2026, 1, 1), amount: 500, origin: "Line 2")
    ]

    assert_no_difference [ "Account.count", "AccountValue.count" ] do
      plan = PortfolioImport.new(rows).preview
      assert_not plan.success?
      assert_match(/credit cards do not track balances/, plan.errors.first)
      assert_match(/credit cards do not track balances/, plan.entries.first.error)
    end
  end

  test "preview rejects unknown kind" do
    rows = [
      PortfolioRow.new(name: "Mystery", institution: "Bank", kind: "hedge_fund",
                       recorded_on: Date.new(2026, 1, 1), amount: 1, origin: "Line 2")
    ]

    plan = PortfolioImport.new(rows).preview

    assert_not plan.success?
    assert_match(/kind must be one of/, plan.errors.first)
    assert_nil plan.entries.first.account_action
  end

  test "account_id updates an existing account instead of creating" do
    tfsa = accounts(:managed_tfsa)

    result = PortfolioImport.new([
      PortfolioRow.new(account_id: tfsa.id, name: "Renamed TFSA", institution: tfsa.institution, kind: "tfsa")
    ]).call

    assert result.success?, result.errors.inspect
    assert_equal 0, result.accounts_created
    assert_equal 1, result.accounts_updated
    assert_equal "Renamed TFSA", tfsa.reload.name
    assert_equal 1, Account.where(name: "Renamed TFSA").count
  end

  test "value_id updates an existing snapshot" do
    value = account_values(:managed_tfsa_june)
    tfsa = value.account

    result = PortfolioImport.new([
      PortfolioRow.new(
        account_id: tfsa.id, value_id: value.id, name: tfsa.name, institution: tfsa.institution,
        kind: tfsa.kind, recorded_on: value.recorded_on, amount: 99_999
      )
    ]).call

    assert result.success?, result.errors.inspect
    assert_equal BigDecimal("99999"), value.reload.amount
    assert_equal 2, tfsa.account_values.count
  end

  test "reimporting an export is idempotent" do
    tfsa = accounts(:managed_tfsa)
    rows = PortfolioExport.rows([ tfsa ])
    value_count = tfsa.account_values.count

    first = PortfolioImport.new(rows).call
    second = PortfolioImport.new(rows).call

    assert first.success?, first.errors.inspect
    assert second.success?, second.errors.inspect
    assert_equal 0, second.accounts_created
    assert_equal 1, Account.where(name: "Managed TFSA", institution: "Wealthsimple").count
    assert_equal value_count, tfsa.account_values.count
  end

  test "unknown account_id falls back to name match then create" do
    result = PortfolioImport.new([
      PortfolioRow.new(account_id: 9_999_999, name: "Brand New TFSA", institution: "WS",
                       kind: "tfsa", recorded_on: Date.new(2026, 1, 1), amount: 10)
    ]).call

    assert result.success?, result.errors.inspect
    assert_equal 1, result.accounts_created
    assert Account.exists?(name: "Brand New TFSA")
  end

  test "committed example csv imports as extra accounts" do
    csv = PortfolioFormats::Csv.example_path.read
    result = import_csv(csv)

    assert result.success?, result.errors.inspect
    assert_equal 4, result.accounts_created
    assert Account.exists?(name: "Example TFSA", institution: "Questrade", kind: "tfsa")
    assert Account.exists?(name: "Example Visa", kind: "credit_card")
    mortgage = Account.find_by!(name: "Example mortgage", institution: "Scotiabank")
    assert_equal "liability", mortgage.kind
    assert_equal 5.14, mortgage.interest_rate.to_f
  end

  test "imports from typed rows without a file format" do
    rows = [
      PortfolioRow.new(name: "Row TFSA", institution: "Bank", kind: "tfsa",
                       recorded_on: Date.new(2026, 1, 1), amount: 1_000)
    ]

    result = PortfolioImport.new(rows).call

    assert result.success?, result.errors.inspect
    assert_equal 1, result.accounts_created
    assert Account.exists?(name: "Row TFSA", kind: "tfsa")
  end

  test "imports new accounts and monthly values" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount,interest_rate,term_months,original_principal
      Import TFSA,Import Bank,tfsa,2026-01-15,42000,,,
      Import TFSA,Import Bank,tfsa,2026-02-01,43000.50,,,
      Import mortgage,Import Bank,liability,2026-01-01,-318000,4.89,60,450000
    CSV

    result = import_csv(csv)

    assert result.success?, result.errors.inspect
    assert_equal 2, result.accounts_created
    assert_equal 0, result.accounts_updated
    assert_equal 3, result.values_upserted

    tfsa = Account.find_by!(name: "Import TFSA", institution: "Import Bank")
    assert_equal "tfsa", tfsa.kind
    assert_equal 2, tfsa.account_values.count
    assert_equal Date.new(2026, 1, 1), tfsa.account_values.chronological.first.recorded_on
    assert_equal BigDecimal("42000"), tfsa.account_values.chronological.first.amount
  end

  test "reimport upserts values and matches existing accounts" do
    account = Account.create!(name: "Import RRSP", institution: "WS", kind: "rrsp")
    AccountValue.create!(account: account, recorded_on: Date.new(2026, 1, 1), amount: 10_000)

    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Import RRSP,WS,rrsp,2026-01-01,11000
      Import RRSP,WS,rrsp,2026-02-01,12000
    CSV

    result = import_csv(csv)

    assert result.success?, result.errors.inspect
    assert_equal 0, result.accounts_created
    assert_equal 1, result.accounts_updated
    assert_equal 2, result.values_upserted
    assert_equal 1, Account.where(name: "Import RRSP").count
    assert_equal BigDecimal("11000"), account.account_values.find_by!(recorded_on: Date.new(2026, 1, 1)).amount
  end

  test "creates credit card without balance" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Import Visa,TD,credit_card,,
    CSV

    result = import_csv(csv)

    assert result.success?, result.errors.inspect
    assert_equal 1, result.accounts_created
    assert_equal 0, result.values_upserted
    assert Account.exists?(name: "Import Visa", kind: "credit_card")
  end

  test "rejects credit card with a value" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Import Visa Bad,TD,credit_card,2026-01-01,500
    CSV

    result = import_csv(csv)

    assert_not result.success?
    assert_match(/credit cards do not track balances/, result.errors.first)
    assert_equal 0, Account.where(name: "Import Visa Bad").count
  end

  test "rejects unknown kind" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Mystery,Bank,hedge_fund,2026-01-01,1
    CSV

    result = import_csv(csv)

    assert_not result.success?
    assert_match(/kind must be one of/, result.errors.first)
  end

  test "rejects malformed amount" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Import Cash,Bank,cash,2026-01-01,not-a-number
    CSV

    result = import_csv(csv)

    assert_not result.success?
    assert_match(/amount is not a number/, result.errors.first)
  end

  test "parses currency-formatted amounts" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Import Formatted,Bank,cash,2026-01-01,"$1,234.56"
    CSV

    result = import_csv(csv)

    assert result.success?, result.errors.inspect
    account = Account.find_by!(name: "Import Formatted")
    assert_equal BigDecimal("1234.56"), account.account_values.last.amount
  end

  test "requires headers" do
    csv = <<~CSV
      foo,bar
      a,b
    CSV

    result = import_csv(csv)

    assert_not result.success?
    assert_match(/Missing required column/, result.errors.first)
  end
end
