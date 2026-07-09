require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "is valid with a name and a known kind" do
    account = Account.new(name: "Managed TFSA", institution: "Wealthsimple", kind: "tfsa")
    assert account.valid?
  end

  test "requires a name" do
    account = Account.new(name: nil, kind: "tfsa")
    assert_not account.valid?
    assert_includes account.errors[:name], "can't be blank"
  end

  test "rejects an unknown kind" do
    account = Account.new(name: "Mystery", kind: "gold_bars")
    assert_not account.valid?
    assert_includes account.errors[:kind], "is not included in the list"
  end

  test "kind_label upcases registered account kinds" do
    assert_equal "TFSA", accounts(:managed_tfsa).kind_label
    assert_equal "RRSP", accounts(:rrsp).kind_label
  end

  test "kind_label humanizes other kinds" do
    assert_equal "Liability", accounts(:mortgage).kind_label
  end

  test "latest_value returns the most recent snapshot" do
    assert_equal account_values(:managed_tfsa_june), accounts(:managed_tfsa).latest_value
  end

  test "current_amount returns the latest snapshot's amount" do
    assert_equal account_values(:managed_tfsa_june).amount, accounts(:managed_tfsa).current_amount
  end

  test "current_amount is nil when no values are recorded" do
    assert_nil accounts(:rrsp).current_amount
  end
end
