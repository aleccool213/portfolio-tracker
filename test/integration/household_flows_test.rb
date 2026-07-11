require "test_helper"

# Synthetic end-to-end flows: real Rails stack over HTTP (no browser).
# These catch wiring bugs across controllers, views, redirects, and DB state
# that single-action controller tests can miss.
class HouseholdFlowsTest < ActionDispatch::IntegrationTest
  test "monthly check-in flow clears the dashboard reminder" do
    month = Date.current.beginning_of_month

    get root_url
    assert_response :success
    assert_select ".reminder strong", text: /time for a check-in/
    assert_select "a[href=?]", value_entry_path

    get value_entry_url
    assert_response :success
    assert_select "form"

    values = {}
    Account.where.not(kind: "credit_card").find_each do |account|
      values[account.id] = account.current_amount || 1_000
    end
    # Credit cards must be ignored even if someone posts them.
    card = accounts(:aeroplan)
    values[card.id] = 999

    post value_entry_url, params: { values: values }
    assert_redirected_to root_path
    follow_redirect!

    assert_match(/Saved this month's values/, flash[:notice].to_s)
    assert_select ".reminder strong", text: /all caught up/
    assert_select ".reminder a", count: 0

    Account.where.not(kind: "credit_card").find_each do |account|
      assert AccountValue.exists?(account: account, recorded_on: month)
    end
    assert_not AccountValue.exists?(account: card, recorded_on: month)
  end

  test "add edit and delete an account through the dashboard" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", new_account_path

    get new_account_url
    assert_response :success

    assert_difference -> { Account.count }, 1 do
      post accounts_url, params: {
        account: { name: "Travel FHSA", institution: "Wealthsimple", kind: "fhsa" }
      }
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".card .name", text: "Travel FHSA"

    account = Account.find_by!(name: "Travel FHSA")
    get edit_account_url(account)
    assert_response :success

    patch account_url(account), params: {
      account: { name: "First-home FHSA", institution: "Wealthsimple", kind: "fhsa" }
    }
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".card .name", text: "First-home FHSA"
    assert_select ".card .name", text: "Travel FHSA", count: 0

    account = Account.find_by!(name: "First-home FHSA")
    assert_difference -> { Account.count }, -1 do
      delete account_url(account)
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".card .name", text: "First-home FHSA", count: 0
  end

  test "liability create requires mortgage fields and then shows rate on dashboard" do
    assert_no_difference -> { Account.count } do
      post accounts_url, params: {
        account: { name: "Cottage loan", institution: "RBC", kind: "liability" }
      }
    end
    assert_response :unprocessable_entity
    assert_select ".form-errors"

    assert_difference -> { Account.count }, 1 do
      post accounts_url, params: {
        account: {
          name: "Cottage loan",
          institution: "RBC",
          kind: "liability",
          interest_rate: 5.25,
          term_months: 48,
          original_principal: 200_000
        }
      }
    end
    assert_redirected_to root_path
    follow_redirect!

    assert_select ".card .name", text: "Cottage loan"
    assert_select ".liability-meta", text: /5\.25/
    assert_select ".liability-meta", text: /4 yr term/
  end

  test "dashboard still assembles after seed-like portfolio exists" do
    # Ensure a fuller household: current-month values + the fixture set.
    month = Date.current.beginning_of_month
    Account.where.not(kind: "credit_card").find_each do |account|
      AccountValue.find_or_create_by!(account: account, recorded_on: month) do |value|
        value.amount = account.current_amount || 10_000
      end
    end

    get root_url
    assert_response :success

    assert_select ".hero .label", text: "Net worth"
    assert_select ".hero .value"
    assert_select ".allocation .alloc-bar"
    assert_select ".card:not(.card-perk) svg.sparkline", minimum: 1
    assert_select ".card-perk .name", text: "Aeroplan Visa Infinite"
    assert_select ".section-title", text: "Your cards"
    assert_select ".reminder strong", text: /all caught up/
  end
end
