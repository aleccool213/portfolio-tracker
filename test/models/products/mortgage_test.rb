require "test_helper"

class Products::MortgageTest < ActiveSupport::TestCase
  test "rate_line formats interest rate and term" do
    mortgage = Products::Mortgage.new(accounts(:mortgage))
    assert_equal "4.89% · 5 yr term", mortgage.rate_line
  end

  test "rate_line is nil without an interest rate" do
    account = Account.new(name: "No rate", kind: "liability")
    assert_nil Products::Mortgage.new(account).rate_line
  end
end
