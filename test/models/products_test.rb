require "test_helper"

class ProductsTest < ActiveSupport::TestCase
  test "wraps liability accounts as Products::Mortgage" do
    assert_instance_of Products::Mortgage, Products.wrap(accounts(:mortgage))
  end

  test "wraps credit-card accounts as Products::CreditCard" do
    assert_instance_of Products::CreditCard, Products.wrap(accounts(:aeroplan))
  end

  test "wraps every other kind as Products::Asset" do
    assert_instance_of Products::Asset, Products.wrap(accounts(:managed_tfsa))
    assert_instance_of Products::Asset, Products.wrap(accounts(:rrsp))
  end

  test "wrap_all wraps a collection in order" do
    products = Products.wrap_all([ accounts(:managed_tfsa), accounts(:mortgage) ])
    assert_equal [ Products::Asset, Products::Mortgage ], products.map(&:class)
  end
end
