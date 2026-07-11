require "test_helper"

class MonthlyChangeTest < ActiveSupport::TestCase
  test "returns an up change when the latest amount is higher" do
    # managed_tfsa: May 42_000 → June 43_500 ≈ +3.6%
    change = MonthlyChange.for(accounts(:managed_tfsa))

    assert_not_nil change
    assert_equal :up, change.direction
    assert_in_delta 3.6, change.pct, 0.05
  end

  test "returns a down change when the latest amount is lower" do
    account = accounts(:rrsp)
    AccountValue.create!(account: account, recorded_on: Date.new(2026, 5, 1), amount: 10_000)
    AccountValue.create!(account: account, recorded_on: Date.new(2026, 6, 1), amount: 9_000)

    change = MonthlyChange.for(account)

    assert_not_nil change
    assert_equal :down, change.direction
    assert_in_delta(-10.0, change.pct, 0.05)
  end

  test "returns flat when the amount is unchanged" do
    account = accounts(:rrsp)
    AccountValue.create!(account: account, recorded_on: Date.new(2026, 5, 1), amount: 5_000)
    AccountValue.create!(account: account, recorded_on: Date.new(2026, 6, 1), amount: 5_000)

    change = MonthlyChange.for(account)

    assert_not_nil change
    assert_equal :flat, change.direction
    assert_equal 0.0, change.pct
  end

  test "returns nil when there is only one snapshot" do
    # mortgage fixture has a single June value
    assert_nil MonthlyChange.for(accounts(:mortgage))
  end

  test "returns nil when there are no snapshots" do
    assert_nil MonthlyChange.for(accounts(:rrsp))
  end

  test "returns nil when the prior amount is zero" do
    account = accounts(:rrsp)
    AccountValue.create!(account: account, recorded_on: Date.new(2026, 5, 1), amount: 0)
    AccountValue.create!(account: account, recorded_on: Date.new(2026, 6, 1), amount: 1_000)

    assert_nil MonthlyChange.for(account)
  end
end
