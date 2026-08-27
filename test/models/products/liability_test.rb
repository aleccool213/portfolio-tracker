require "test_helper"

class Products::LiabilityTest < ActiveSupport::TestCase
  test "is trackable but not an asset" do
    liability = Products::Liability.new(accounts(:mortgage))
    assert liability.trackable?
    assert_not liability.asset?
  end

  test "net_worth_contribution is always negative, regardless of stored sign" do
    liability = Products::Liability.new(accounts(:mortgage))
    assert_equal BigDecimal("-318000"), liability.net_worth_contribution

    account = accounts(:mortgage)
    account.account_values.destroy_all
    AccountValue.create!(account: account, recorded_on: Date.new(2026, 7, 1), amount: 200_000)

    assert_equal BigDecimal("-200000"), Products::Liability.new(account.reload).net_worth_contribution
  end

  test "net_worth_contribution is zero with no snapshots" do
    account = Account.new(name: "Fresh liability", kind: "liability")
    assert_equal 0, Products::Liability.new(account).net_worth_contribution
  end
end
