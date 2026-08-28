require "application_system_test_case"

class AccountFormTest < ApplicationSystemTestCase
  test "shows only the detail fields for the selected product type" do
    visit new_account_path

    assert_no_selector "legend", text: "Mortgage details"
    assert_no_selector "legend", text: "Card details"

    select "TFSA", from: "Kind"
    assert_selector "legend", text: "Asset details"
    assert_no_selector "legend", text: "Mortgage details"
    assert_no_selector "legend", text: "Card details"

    select "Liability", from: "Kind"
    assert_selector "legend", text: "Mortgage details"
    assert_no_selector "legend", text: "Asset details"
    assert_no_selector "legend", text: "Card details"

    select "Credit card", from: "Kind"
    assert_selector "legend", text: "Card details"
    assert_no_selector "legend", text: "Mortgage details"
  end

  test "creates a mortgage with its detail fields" do
    visit new_account_path

    fill_in "Name", with: "Cottage mortgage"
    fill_in "Institution", with: "RBC"
    select "Liability", from: "Kind"
    fill_in "Interest rate (%)", with: "5.25"
    fill_in "Term (months)", with: "60"
    fill_in "Original principal", with: "250000"
    click_on "Create Account"

    assert_text "Account added"
    assert_text "Cottage mortgage"
    assert_text "5.25%"
  end
end
