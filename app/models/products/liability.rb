module Products
  # A valued product that decreases net worth. Sign lives here: contribution
  # is always -amount.abs, regardless of how the balance was stored.
  class Liability < ValuedProduct
    private

    def signed_amount(amount)
      amount.nil? ? 0 : -amount.abs
    end
  end
end
