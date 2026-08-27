require "test_helper"

class Products::AssetTest < ActiveSupport::TestCase
  setup do
    @product = Products.wrap(accounts(:managed_tfsa))
  end

  test "is a trackable asset" do
    assert @product.trackable?
    assert @product.asset?
  end

  test "contributes its current amount to net worth" do
    assert_equal BigDecimal("43500"), @product.net_worth_contribution
  end

  test "contributes zero when nothing is recorded yet" do
    assert_equal 0, Products.wrap(accounts(:rrsp)).net_worth_contribution
  end

  test "amount_on reads a specific month" do
    assert_equal BigDecimal("42000"), @product.amount_on(Date.new(2026, 5, 1))
    assert_nil @product.amount_on(Date.new(2026, 4, 1))
  end

  test "record_amount upserts the month's snapshot" do
    month = Date.current.beginning_of_month

    assert_difference -> { AccountValue.count }, 1 do
      @product.record_amount(month, "44_000.50".delete("_"))
    end
    assert_equal BigDecimal("44000.5"), @product.amount_on(month)

    assert_no_difference -> { AccountValue.count } do
      @product.record_amount(month, 45_000)
    end
    assert_equal BigDecimal("45000"), @product.amount_on(month)
  end

  test "chronological_amounts runs oldest first" do
    assert_equal [ BigDecimal("42000"), BigDecimal("43500") ], @product.chronological_amounts
  end

  test "has no rate line" do
    assert_not @product.rate_line?
  end
end
