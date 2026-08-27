module Products
  # A valued product that increases net worth. Its `kind` is a tax sleeve
  # (tfsa, rrsp, cash, ...), not a product type.
  class Asset < ValuedProduct
    def asset?
      true
    end
  end
end
