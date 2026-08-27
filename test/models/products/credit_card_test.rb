require "test_helper"

class Products::CreditCardTest < ActiveSupport::TestCase
  test "is not trackable, not an asset, and contributes nothing to net worth" do
    card = Products::CreditCard.new(accounts(:aeroplan))
    assert_not card.trackable?
    assert_not card.asset?
    assert_equal 0, card.net_worth_contribution
  end
end
