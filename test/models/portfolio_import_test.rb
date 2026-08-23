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
