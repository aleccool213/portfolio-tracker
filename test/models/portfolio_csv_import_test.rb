require "test_helper"
require "stringio"

class PortfolioCsvImportTest < ActiveSupport::TestCase
  test "imports new accounts and monthly values" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Import TFSA,Import Bank,tfsa,2026-01-15,42000
      Import TFSA,Import Bank,tfsa,2026-02-01,43000.50
      Import mortgage,Import Bank,liability,2026-01-01,-318000
    CSV

    result = PortfolioCsvImport.new(StringIO.new(csv)).call

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

    result = PortfolioCsvImport.new(StringIO.new(csv)).call

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

    result = PortfolioCsvImport.new(StringIO.new(csv)).call

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

    result = PortfolioCsvImport.new(StringIO.new(csv)).call

    assert_not result.success?
    assert_match(/credit cards do not track balances/, result.errors.first)
    assert_equal 0, Account.where(name: "Import Visa Bad").count
  end

  test "rejects unknown kind" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Mystery,Bank,hedge_fund,2026-01-01,1
    CSV

    result = PortfolioCsvImport.new(StringIO.new(csv)).call

    assert_not result.success?
    assert_match(/kind must be one of/, result.errors.first)
  end

  test "rejects malformed amount" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Import Cash,Bank,cash,2026-01-01,not-a-number
    CSV

    result = PortfolioCsvImport.new(StringIO.new(csv)).call

    assert_not result.success?
    assert_match(/amount is not a number/, result.errors.first)
  end

  test "parses currency-formatted amounts" do
    csv = <<~CSV
      name,institution,kind,recorded_on,amount
      Import Formatted,Bank,cash,2026-01-01,"$1,234.56"
    CSV

    result = PortfolioCsvImport.new(StringIO.new(csv)).call

    assert result.success?, result.errors.inspect
    account = Account.find_by!(name: "Import Formatted")
    assert_equal BigDecimal("1234.56"), account.account_values.last.amount
  end

  test "requires headers" do
    csv = <<~CSV
      foo,bar
      a,b
    CSV

    result = PortfolioCsvImport.new(StringIO.new(csv)).call

    assert_not result.success?
    assert_match(/Missing required column/, result.errors.first)
  end

  test "template includes expected headers" do
    headers = CSV.parse(PortfolioCsvImport.template_csv, headers: true).headers
    assert_equal PortfolioCsvImport::HEADERS, headers
  end
end
