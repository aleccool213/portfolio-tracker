require "test_helper"

class PortfolioTest < ActiveSupport::TestCase
  setup do
    @accounts = Account.order(:kind, :name).to_a
    @portfolio = Portfolio.new(@accounts)
  end

  test "net_worth sums assets and signed liabilities" do
    # managed_tfsa current 43_500 + rrsp nil + mortgage -318_000
    assert_equal BigDecimal("-274500"), @portfolio.net_worth
  end

  test "net_worth ignores credit cards" do
    card = Account.create!(name: "Test Card", institution: "TD", kind: "credit_card")
    AccountValue.create!(account: card, recorded_on: Date.new(2026, 6, 1), amount: 9_999)

    portfolio = Portfolio.new(@accounts + [ card ])
    assert_equal BigDecimal("-274500"), portfolio.net_worth
  end

  test "net_worth treats a positive liability amount as negative" do
    mortgage = accounts(:mortgage)
    mortgage.account_values.destroy_all
    AccountValue.create!(account: mortgage, recorded_on: Date.new(2026, 6, 1), amount: 200_000)

    portfolio = Portfolio.new([ accounts(:managed_tfsa), mortgage ])
    # 43_500 + (-200_000)
    assert_equal BigDecimal("-156500"), portfolio.net_worth
  end

  test "monthly_change is nil when the current month has no snapshots" do
    # Fixtures only have May/June; today is past June in this project timeline.
    assert_nil @portfolio.monthly_change
  end

  test "monthly_change reports an up swing when the portfolio grows" do
    month = Date.current.beginning_of_month
    prior = month.prev_month

    seed_month_values(
      prior => { managed_tfsa: 40_000, mortgage: -300_000 },
      month => { managed_tfsa: 50_000, mortgage: -290_000 }
    )

    change = Portfolio.new(Account.order(:kind, :name).to_a).monthly_change

    assert_not_nil change
    assert_equal :up, change.direction
    # prior net = -260_000, current net = -240_000 → +7.7% of |prior|
    assert_in_delta 7.7, change.pct, 0.05
  end

  test "monthly_change reports a down swing when the portfolio shrinks" do
    month = Date.current.beginning_of_month
    prior = month.prev_month

    seed_month_values(
      prior => { managed_tfsa: 50_000, mortgage: -200_000 },
      month => { managed_tfsa: 40_000, mortgage: -200_000 }
    )

    change = Portfolio.new(Account.order(:kind, :name).to_a).monthly_change

    assert_not_nil change
    assert_equal :down, change.direction
    # prior net = -150_000, current = -160_000 → -6.7%
    assert_in_delta(-6.7, change.pct, 0.05)
  end

  test "needs_check_in? is true when a trackable account lacks this month" do
    assert @portfolio.needs_check_in?
  end

  test "needs_check_in? is false when every trackable account has this month" do
    month = Date.current.beginning_of_month
    Account.where.not(kind: "credit_card").find_each do |account|
      AccountValue.find_or_create_by!(account: account, recorded_on: month) do |value|
        value.amount = account.current_amount || 0
      end
    end

    assert_not Portfolio.new(Account.order(:kind, :name).to_a).needs_check_in?
  end

  test "needs_check_in? ignores credit cards" do
    month = Date.current.beginning_of_month
    Account.where.not(kind: "credit_card").find_each do |account|
      AccountValue.find_or_create_by!(account: account, recorded_on: month) do |value|
        value.amount = account.current_amount || 0
      end
    end
    Account.create!(name: "Orphan Card", institution: "TD", kind: "credit_card")

    assert_not Portfolio.new(Account.order(:kind, :name).to_a).needs_check_in?
  end

  private

  def seed_month_values(months_to_amounts)
    AccountValue.delete_all

    months_to_amounts.each do |recorded_on, by_fixture|
      by_fixture.each do |fixture_name, amount|
        AccountValue.create!(
          account: accounts(fixture_name),
          recorded_on: recorded_on,
          amount: amount
        )
      end
    end
  end
end
