require "test_helper"

class ProductsTest < ActiveSupport::TestCase
  test "wraps each kind in its product class" do
    assert_instance_of Products::Asset, Products.wrap(accounts(:managed_tfsa))
    assert_instance_of Products::Mortgage, Products.wrap(accounts(:mortgage))
    assert_instance_of Products::CreditCard, Products.wrap(accounts(:aeroplan))
  end

  test "every asset sleeve wraps as an asset" do
    %w[tfsa rrsp resp fhsa non_registered crypto cash].each do |kind|
      assert_instance_of Products::Asset, Products.wrap(Account.new(name: "x", kind: kind))
    end
  end

  test "wrap_all keeps order and accepts a relation" do
    products = Products.wrap_all(Account.order(:name))
    assert_equal Account.order(:name).map(&:id), products.map(&:id)
  end

  test "kinds_for lists the kinds that map to a product class" do
    assert_equal [ "liability" ], Products.kinds_for(Products::Mortgage)
    assert_equal [ "credit_card" ], Products.kinds_for(Products::CreditCard)
    assert_includes Products.kinds_for(Products::Asset), "tfsa"
    assert_not_includes Products.kinds_for(Products::Asset), "liability"
  end

  test "products delegate identity to the account row" do
    product = Products.wrap(accounts(:managed_tfsa))
    assert_equal accounts(:managed_tfsa).id, product.id
    assert_equal "Managed TFSA", product.name
    assert_equal "Wealthsimple", product.institution
    assert_equal "TFSA", product.kind_label
    assert_equal accounts(:managed_tfsa), product.record
  end
end
