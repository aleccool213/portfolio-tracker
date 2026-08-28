require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "new renders the form" do
    get new_account_url
    assert_response :success
    assert_select "form"
    assert_select "input[name=?]", "account[name]"
    assert_select "select[name=?]", "account[kind]"
  end

  test "new renders one field group per product type" do
    get new_account_url
    assert_select "fieldset.field-group", 3
    assert_select "fieldset.field-group[data-kinds=?]", "liability"
    assert_select "fieldset.field-group[data-kinds=?]", "credit_card"
    assert_select "fieldset.field-group[data-kinds*=?]", "tfsa"
    assert_select "select[data-account-fields-target=?]", "kind"
  end

  test "create with valid params adds an account" do
    assert_difference -> { Account.count }, 1 do
      post accounts_url, params: {
        account: { name: "Family FHSA", institution: "Wealthsimple", kind: "fhsa" }
      }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_match(/Account added/, flash[:notice].to_s)
    assert Account.exists?(name: "Family FHSA", kind: "fhsa")
  end

  test "create with invalid params re-renders the form with errors" do
    assert_no_difference -> { Account.count } do
      post accounts_url, params: {
        account: { name: "", institution: "Wealthsimple", kind: "tfsa" }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors"
  end

  test "edit renders the form for an existing account" do
    account = accounts(:managed_tfsa)
    get edit_account_url(account)
    assert_response :success
    assert_select "input[name=?][value=?]", "account[name]", account.name
  end

  test "update changes account attributes" do
    account = accounts(:rrsp)
    patch account_url(account), params: {
      account: { name: "Spousal RRSP", institution: "Wealthsimple", kind: "rrsp" }
    }

    assert_redirected_to root_path
    assert_equal "Spousal RRSP", account.reload.name
  end

  test "destroy removes the account and its values" do
    account = accounts(:managed_tfsa)
    assert account.account_values.any?

    assert_difference -> { Account.count }, -1 do
      assert_difference -> { AccountValue.count }, -account.account_values.count do
        delete account_url(account)
      end
    end

    assert_redirected_to root_path
    assert_not Account.exists?(account.id)
  end
end
