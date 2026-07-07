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
end
