# Asset allocation by account kind, plus gentle concentration nudges.
# Liabilities and credit cards are excluded — this is about how assets are parked.
class Allocation
  CASH_THRESHOLD = 25.0 # percent of assets
  ACCOUNT_THRESHOLD = 50.0 # single account share of assets

  Slice = Data.define(:kind, :label, :amount, :pct)
  Nudge = Data.define(:key, :message)

  def initialize(accounts)
    @products = Products.wrap_all(accounts)
  end

  def asset_products
    @asset_products ||= @products.select(&:asset?)
  end

  def total_assets
    @total_assets ||= asset_products.sum { |product| positive_amount(product) }
  end

  def slices
    return [] if total_assets.zero?

    by_kind = asset_products.group_by { |product| product.record.kind }.filter_map do |kind, products|
      amount = products.sum { |product| positive_amount(product) }
      next if amount.zero?

      pct = (amount / total_assets * 100).round(1)
      Slice.new(kind: kind, label: Account.kind_label_for(kind), amount: amount, pct: pct)
    end

    by_kind.sort_by { |s| -s.amount }
  end

  def nudges
    list = []
    return list if total_assets.zero?

    cash_pct = kind_pct("cash")
    if cash_pct > CASH_THRESHOLD
      list << Nudge.new(
        key: :cash_heavy,
        message: "You're heavy in cash (#{cash_pct.round}%) — consider investing some when you're ready."
      )
    end

    asset_products.each do |product|
      amount = positive_amount(product)
      next if amount.zero?

      share = (amount / total_assets * 100).round(1)
      next unless share > ACCOUNT_THRESHOLD

      list << Nudge.new(
        key: :"concentrated_#{product.id}",
        message: "#{product.name} is #{share.round}% of your assets — a little diversification could help you sleep better."
      )
    end

    list
  end

  private

  def positive_amount(product)
    amount = product.current_amount
    return 0 if amount.nil?

    amount.positive? ? amount : 0
  end

  def kind_pct(kind)
    amount = asset_products.select { |product| product.record.kind == kind }.sum { |product| positive_amount(product) }
    return 0 if total_assets.zero?

    (amount / total_assets * 100).round(1)
  end
end
