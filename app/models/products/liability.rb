module Products
  # A valued product that decreases net worth. The sign convention lives here,
  # so it doesn't matter whether a balance owed was entered positive or negative.
  class Liability < Base
    private

    def signed(amount)
      return 0 if amount.nil?

      -amount.abs
    end
  end
end
