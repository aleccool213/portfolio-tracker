require "test_helper"

class AccountValueTest < ActiveSupport::TestCase
  test "is valid with an account, recorded_on and amount" do
    value = AccountValue.new(account: accounts(:rrsp), recorded_on: Date.current, amount: 100)
    assert value.valid?
  end

  test "belongs to an account" do
    assert_equal accounts(:managed_tfsa), account_values(:managed_tfsa_june).account
  end

  test "requires a recorded_on" do
    value = AccountValue.new(account: accounts(:rrsp), recorded_on: nil, amount: 100)
    assert_not value.valid?
    assert_includes value.errors[:recorded_on], "can't be blank"
  end

  test "requires an amount" do
    value = AccountValue.new(account: accounts(:rrsp), recorded_on: Date.current, amount: nil)
    assert_not value.valid?
    assert_includes value.errors[:amount], "can't be blank"
  end

  test "rejects a non-numeric amount" do
    value = AccountValue.new(account: accounts(:rrsp), recorded_on: Date.current, amount: "lots")
    assert_not value.valid?
    assert_includes value.errors[:amount], "is not a number"
  end

  test "allows a negative amount for liabilities" do
    value = AccountValue.new(account: accounts(:mortgage), recorded_on: Date.current, amount: -250_000)
    assert value.valid?
  end

  test "chronological scope orders oldest first" do
    ordered = accounts(:managed_tfsa).account_values.chronological.to_a
    assert_equal ordered.sort_by(&:recorded_on), ordered
    assert_equal account_values(:managed_tfsa_may), ordered.first
  end
end
