require "test_helper"
require "stringio"

class PortfolioCsvExportTest < ActiveSupport::TestCase
  test "exports a valued account as one row per snapshot" do
    csv = PortfolioCsvExport.call([ accounts(:managed_tfsa) ])
    rows = CSV.parse(csv, headers: true)

    assert_equal PortfolioCsvImport::HEADERS, rows.headers
    assert_equal 2, rows.size
    assert_equal [ "2026-05-01", "2026-06-01" ], rows.map { |r| r["recorded_on"] }
    assert_equal "Managed TFSA", rows.first["name"]
    assert_equal "tfsa", rows.first["kind"]
    assert_equal "42000.0", rows.first["amount"]
  end

  test "exports a liability with rate term and principal" do
    csv = PortfolioCsvExport.call([ accounts(:mortgage) ])
    row = CSV.parse(csv, headers: true).first

    assert_equal "Home mortgage", row["name"]
    assert_equal "liability", row["kind"]
    assert_equal "2026-06-01", row["recorded_on"]
    assert_equal "-318000.0", row["amount"]
    assert_equal "4.89", row["interest_rate"]
    assert_equal "60", row["term_months"]
    assert_equal "450000.0", row["original_principal"]
  end

  test "exports a credit card as a single blank-value row" do
    csv = PortfolioCsvExport.call([ accounts(:aeroplan) ])
    rows = CSV.parse(csv, headers: true)

    assert_equal 1, rows.size
    assert_equal "credit_card", rows.first["kind"]
    assert_nil rows.first["recorded_on"]
    assert_nil rows.first["amount"]
  end

  test "exported csv reimports onto a fresh account" do
    exported = PortfolioCsvExport.call([ accounts(:managed_tfsa) ])
    accounts(:managed_tfsa).account_values.destroy_all
    accounts(:managed_tfsa).destroy

    result = PortfolioCsvImport.new(StringIO.new(exported)).call

    assert result.success?, result.errors.inspect
    restored = Account.find_by!(name: "Managed TFSA", institution: "Wealthsimple")
    assert_equal 2, restored.account_values.count
    assert_equal BigDecimal("43500.0"), restored.account_values.chronological.last.amount
  end
end
