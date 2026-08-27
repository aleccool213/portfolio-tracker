# Wraps an Account row in a product object that knows its role
# (asset, liability, credit card) so callers stop branching on `kind`.
module Products
  def self.wrap(account)
    case account.kind
    when "credit_card"
      Products::CreditCard.new(account)
    when "liability"
      Products::Mortgage.new(account)
    else
      Products::Asset.new(account)
    end
  end

  def self.wrap_all(accounts)
    Array(accounts).map { |account| wrap(account) }
  end
end
