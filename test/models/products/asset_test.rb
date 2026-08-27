require "test_helper"

class Products::AssetTest < ActiveSupport::TestCase
  test "is trackable and an asset" do
    asset = Products::Asset.new(accounts(:managed_tfsa))
    assert asset.trackable?
    assert asset.asset?
  end

  test "net_worth_contribution is the current amount" do
    asset = Products::Asset.new(accounts(:managed_tfsa))
    assert_equal BigDecimal("43500"), asset.net_worth_contribution
  end

  test "net_worth_contribution is zero with no snapshots" do
    asset = Products::Asset.new(accounts(:rrsp))
    assert_equal 0, asset.net_worth_contribution
  end
end
