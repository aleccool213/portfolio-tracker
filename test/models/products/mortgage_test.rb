require "test_helper"

class Products::MortgageTest < ActiveSupport::TestCase
  setup do
    @product = Products.wrap(accounts(:mortgage))
  end

  test "is a trackable liability, not an asset" do
    assert @product.trackable?
    assert_not @product.asset?
    assert_kind_of Products::Liability, @product
  end

  test "always pulls net worth down, whichever sign was entered" do
    assert_equal BigDecimal("-318000"), @product.net_worth_contribution

    @product.record.account_values.destroy_all
    @product.record.account_values.reload
    @product.record_amount(Date.new(2026, 7, 1), 200_000)

    assert_equal BigDecimal("-200000"), @product.net_worth_contribution
  end

  test "contributes zero when nothing is recorded yet" do
    account = Account.create!(
      name: "New mortgage", kind: "liability",
      interest_rate: 4.0, term_months: 60, original_principal: 300_000
    )
    assert_equal 0, Products.wrap(account).net_worth_contribution
  end

  test "net_worth_contribution_on signs a specific month" do
    assert_equal BigDecimal("-318000"), @product.net_worth_contribution_on(Date.new(2026, 6, 1))
    assert_equal 0, @product.net_worth_contribution_on(Date.new(2026, 5, 1))
  end

  test "exposes a rate line with the term in years" do
    assert @product.rate_line?
    assert_equal 4.89, @product.interest_rate.to_f
    assert_equal 5, @product.term_years
  end

  test "rate_line? is false without a rate" do
    account = Account.new(name: "Mortgage", kind: "liability")
    assert_not Products.wrap(account).rate_line?
    assert_nil Products.wrap(account).term_years
  end
end
