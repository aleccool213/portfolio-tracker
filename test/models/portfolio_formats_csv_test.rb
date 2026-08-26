require "test_helper"
require "stringio"

class PortfolioFormatsCsvTest < ActiveSupport::TestCase
  test "example csv is the committed template and parses cleanly" do
    path = PortfolioFormats::Csv.example_path
    assert path.exist?
    assert_equal path.read, PortfolioFormats::Csv.template

    headers = CSV.parse(PortfolioFormats::Csv.template, headers: true).headers
    assert_equal PortfolioFormats::Csv::HEADERS, headers

    decoded = PortfolioFormats::Csv.parse(path.open)
    assert_empty decoded.errors
    assert decoded.rows.size >= 4
  end

  test "generate then parse round-trips typed rows" do
    original = [
      PortfolioRow.new(account_id: 12, value_id: 34, name: "Round TFSA", institution: "WS", kind: "tfsa",
                       recorded_on: Date.new(2026, 3, 1), amount: BigDecimal("100.50"))
    ]

    decoded = PortfolioFormats::Csv.parse(StringIO.new(PortfolioFormats::Csv.generate(original)))

    assert_empty decoded.errors
    assert_equal 1, decoded.rows.size
    assert_equal 12, decoded.rows.first.account_id
    assert_equal 34, decoded.rows.first.value_id
    assert_equal "Round TFSA", decoded.rows.first.name
    assert_equal Date.new(2026, 3, 1), decoded.rows.first.recorded_on
    assert_in_delta 100.50, decoded.rows.first.amount
  end
end
