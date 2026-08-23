require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "root renders the dashboard" do
    get root_url
    assert_response :success
    assert_select "h1", /Hey there/
  end

  test "lists each account by name" do
    get root_url
    assert_select ".card .name", text: "Managed TFSA"
    assert_select ".card .name", text: "Home mortgage"
  end

  test "shows the monthly check-in reminder when values are missing" do
    get root_url
    assert_select ".reminder strong", text: /time for a check-in/
    assert_select ".reminder a[href=?]", value_entry_path
  end

  test "shows a caught-up reminder when every trackable account has this month" do
    month = Date.current.beginning_of_month
    Account.where.not(kind: "credit_card").find_each do |account|
      AccountValue.find_or_create_by!(account: account, recorded_on: month) do |value|
        value.amount = account.current_amount || 0
      end
    end

    get root_url
    assert_select ".reminder strong", text: /all caught up/
    assert_select ".reminder a", count: 0
  end

  test "shows net worth in the hero instead of an account count" do
    get root_url
    assert_select ".hero .label", text: "Net worth"
    # managed_tfsa 43_500 + mortgage -318_000
    assert_select ".hero .value", text: /\$\-?274,500/
    assert_select ".hero .label", text: "Accounts tracked", count: 0
  end

  test "shows a formatted dollar amount for an account with values" do
    get root_url
    assert_select ".card .amount", text: /\$43,500/
  end

  test "shows an em dash for an account with no values" do
    get root_url
    assert_select ".card .amount", text: "—"
  end

  test "shows a month-over-month badge for an account with two months of values" do
    get root_url
    # managed_tfsa: May 42_000 → June 43_500 ≈ +3.6%
    assert_select ".badge.badge-up", text: /▲ \+3\.6%/
  end

  test "shows add and edit account affordances" do
    get root_url
    assert_select "a[href=?]", new_account_path, text: "Add account"
    assert_select "a[href=?]", edit_account_path(accounts(:managed_tfsa)), text: "Edit"
  end

  test "shows mortgage rate and term on liability cards" do
    get root_url
    assert_select ".liability-meta", text: /4\.89/
    assert_select ".liability-meta", text: /5 yr term/
  end
end
