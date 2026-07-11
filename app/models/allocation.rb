# Asset allocation by account kind, plus gentle concentration nudges.
# Liabilities and credit cards are excluded — this is about how assets are parked.
class Allocation
  CASH_THRESHOLD = 25.0 # percent of assets
  ACCOUNT_THRESHOLD = 50.0 # single account share of assets

  Slice = Data.define(:kind, :label, :amount, :pct)
  Nudge = Data.define(:key, :message)

  def initialize(accounts)
    @accounts = Array(accounts)
  end

  def asset_accounts
    @asset_accounts ||= @accounts.reject { |a| a.kind == "credit_card" || a.kind == "liability" }
  end

  def total_assets
    @total_assets ||= asset_accounts.sum { |a| positive_amount(a) }
  end

  def slices
    return [] if total_assets.zero?

    by_kind = asset_accounts.group_by(&:kind).filter_map do |kind, accounts|
      amount = accounts.sum { |a| positive_amount(a) }
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

    asset_accounts.each do |account|
      amount = positive_amount(account)
      next if amount.zero?

      share = (amount / total_assets * 100).round(1)
      next unless share > ACCOUNT_THRESHOLD

      list << Nudge.new(
        key: :"concentrated_#{account.id}",
        message: "#{account.name} is #{share.round}% of your assets — a little diversification could help you sleep better."
      )
    end

    list
  end

  private

  def positive_amount(account)
    amount = account.current_amount
    return 0 if amount.nil?

    amount.positive? ? amount : 0
  end

  def kind_pct(kind)
    amount = asset_accounts.select { |a| a.kind == kind }.sum { |a| positive_amount(a) }
    return 0 if total_assets.zero?

    (amount / total_assets * 100).round(1)
  end
end
