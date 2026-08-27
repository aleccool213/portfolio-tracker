# Products wrap an Account row in an object that owns its behaviour, so callers
# (dashboard, allocation, value entry, suggestions) never branch on `kind`.
#
# `kind` is really two axes: the product type (credit card, mortgage, everything
# else) and, for assets, the tax sleeve it's parked in (TFSA, RRSP, cash...).
# The factory below is the one place the first axis is read; the sleeve stays on
# the record and is what allocation groups by.
module Products
  Error = Class.new(StandardError)
  # Raised when something tries to record a monthly value on a product that
  # doesn't hold one (a credit card).
  NotTrackable = Class.new(Error)

  # The only place in app/ that interprets Account#kind.
  def self.class_for(kind)
    case kind
    when "credit_card" then CreditCard
    when "liability"   then Mortgage
    else                    Asset
    end
  end

  def self.wrap(account)
    class_for(account.kind).new(account)
  end

  def self.wrap_all(accounts)
    Array(accounts).map { |account| wrap(account) }
  end

  # The Account kinds that map to a given product class, e.g. every asset
  # sleeve. Handy for forms that show one field group per product type.
  def self.kinds_for(product_class)
    Account::KINDS.select { |kind| class_for(kind) <= product_class }
  end
end
