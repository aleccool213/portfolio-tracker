require "test_helper"

class AllocationTest < ActiveSupport::TestCase
  test "slices assets by kind as percentages" do
    # managed_tfsa 43_500 only (rrsp has no value; mortgage excluded; card excluded)
    allocation = Allocation.new(Account.order(:kind, :name).to_a)
    slices = allocation.slices

    assert_equal 1, slices.size
    assert_equal "tfsa", slices.first.kind
    assert_equal 100.0, slices.first.pct
    assert_equal BigDecimal("43500"), slices.first.amount
  end

  test "excludes liabilities and credit cards from assets" do
    allocation = Allocation.new(Account.order(:kind, :name).to_a)
    kinds = allocation.slices.map(&:kind)
    assert_not_includes kinds, "liability"
    assert_not_includes kinds, "credit_card"
  end

  test "flags cash concentration above threshold" do
    cash = Account.create!(name: "Big cash", institution: "Bank", kind: "cash")
    AccountValue.create!(account: cash, recorded_on: Date.new(2026, 6, 1), amount: 100_000)
    tfsa = accounts(:managed_tfsa)

    allocation = Allocation.new([ cash, tfsa ])
    messages = allocation.nudges.map(&:message)

    assert messages.any? { |m| m.match?(/heavy in cash/i) }
  end

  test "flags a single account over half of assets" do
    allocation = Allocation.new([ accounts(:managed_tfsa) ])
    messages = allocation.nudges.map(&:message)

    assert messages.any? { |m| m.match?(/Managed TFSA/i) }
  end
end
