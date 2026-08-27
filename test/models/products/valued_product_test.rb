require "test_helper"

class Products::ValuedProductTest < ActiveSupport::TestCase
  test "record_amount upserts this month's snapshot" do
    month = Date.current.beginning_of_month
    product = Products::Asset.new(accounts(:rrsp))

    assert_difference -> { accounts(:rrsp).account_values.where(recorded_on: month).count }, 1 do
      product.record_amount(month, 61_500)
    end
    assert_equal 61_500, accounts(:rrsp).account_values.find_by(recorded_on: month).amount
  end

  test "record_amount updates an existing snapshot instead of duplicating" do
    month = Date.current.beginning_of_month
    product = Products::Asset.new(accounts(:rrsp))
    product.record_amount(month, 61_000)

    assert_no_difference -> { AccountValue.count } do
      product.record_amount(month, 62_000)
    end
    assert_equal 62_000, accounts(:rrsp).account_values.find_by(recorded_on: month).amount
  end
end
