require "test_helper"

class ValueEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @month = Date.current.beginning_of_month
  end

  test "show renders a field per trackable account" do
    get value_entry_url
    assert_response :success
    assert_select "input[name=?]", "values[#{accounts(:managed_tfsa).id}]"
    assert_select "input[name=?]", "values[#{accounts(:rrsp).id}]"
  end

  test "show excludes credit-card accounts" do
    card = Account.create!(name: "Test Card", institution: "TD", kind: "credit_card")
    get value_entry_url
    assert_select "input[name=?]", "values[#{card.id}]", count: 0
  end

  test "show pre-fills the current month's existing value" do
    AccountValue.create!(account: accounts(:rrsp), recorded_on: @month, amount: 61_000)
    get value_entry_url
    assert_select "input[name=?][value=?]", "values[#{accounts(:rrsp).id}]", "61000.0"
  end

  test "create upserts a value for the current month" do
    account = accounts(:rrsp)
    assert_difference -> { account.account_values.where(recorded_on: @month).count }, 1 do
      post value_entry_url, params: { values: { account.id => "61500.25" } }
    end
    assert_redirected_to root_path
    assert_equal 61_500.25, account.account_values.find_by(recorded_on: @month).amount
  end

  test "re-posting updates the existing row instead of duplicating" do
    account = accounts(:rrsp)
    post value_entry_url, params: { values: { account.id => "61000" } }
    assert_no_difference -> { account.account_values.where(recorded_on: @month).count } do
      post value_entry_url, params: { values: { account.id => "62000" } }
    end
    assert_equal 62_000, account.account_values.find_by(recorded_on: @month).amount
  end

  test "blank fields are skipped and leave existing values untouched" do
    account = accounts(:rrsp)
    AccountValue.create!(account: account, recorded_on: @month, amount: 61_000)
    assert_no_difference -> { AccountValue.count } do
      post value_entry_url, params: { values: { account.id => "" } }
    end
    assert_equal 61_000, account.account_values.find_by(recorded_on: @month).amount
  end

  test "create ignores credit-card accounts even if submitted" do
    card = Account.create!(name: "Test Card", institution: "TD", kind: "credit_card")
    assert_no_difference -> { AccountValue.count } do
      post value_entry_url, params: { values: { card.id => "500" } }
    end
  end
end
