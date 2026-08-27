require "test_helper"

class Products::CreditCardTest < ActiveSupport::TestCase
  setup do
    @product = Products.wrap(accounts(:aeroplan))
  end

  test "is neither trackable nor an asset" do
    assert_not @product.trackable?
    assert_not @product.asset?
  end

  test "never touches net worth, even if a value row exists" do
    AccountValue.create!(account: accounts(:aeroplan), recorded_on: Date.new(2026, 6, 1), amount: 9_999)
    accounts(:aeroplan).account_values.reload

    assert_equal 0, @product.net_worth_contribution
    assert_equal 0, @product.net_worth_contribution_on(Date.new(2026, 6, 1))
    assert_nil @product.current_amount
    assert_nil @product.amount_on(Date.new(2026, 6, 1))
    assert_empty @product.chronological_amounts
    assert_nil @product.monthly_change
  end

  test "refuses to record an amount" do
    assert_no_difference -> { AccountValue.count } do
      assert_raises(Products::NotTrackable) do
        @product.record_amount(Date.current.beginning_of_month, 500)
      end
    end
  end

  test "exposes perk details" do
    assert @product.annual_fee?
    assert @product.renewal?
    assert_equal BigDecimal("139"), @product.annual_fee
    assert_match(/Aeroplan points/, @product.perks)
  end
end
