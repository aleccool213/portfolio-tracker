require "test_helper"
require "stringio"

class PortfolioFormatsCsvTest < ActiveSupport::TestCase
  test "template includes expected headers" do
    headers = CSV.parse(PortfolioFormats::Csv.template, headers: true).headers
    assert_equal PortfolioFormats::Csv::HEADERS, headers
  end

  test "generate then parse round-trips typed rows" do
    original = [
      PortfolioRow.new(name: "Round TFSA", institution: "WS", kind: "tfsa",
                       recorded_on: Date.new(2026, 3, 1), amount: BigDecimal("100.50"))
    ]

    decoded = PortfolioFormats::Csv.parse(StringIO.new(PortfolioFormats::Csv.generate(original)))

    assert_empty decoded.errors
    assert_equal 1, decoded.rows.size
    assert_equal "Round TFSA", decoded.rows.first.name
    assert_equal Date.new(2026, 3, 1), decoded.rows.first.recorded_on
    assert_in_delta 100.50, decoded.rows.first.amount
  end
end
