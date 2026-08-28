module Products
  # A valued product that increases net worth. Its `kind` is a tax sleeve
  # (TFSA, RRSP, cash...), not a product type.
  class Asset < Base
    def asset?
      true
    end
  end
end
