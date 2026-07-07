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

  test "shows the monthly check-in reminder" do
    get root_url
    assert_select ".reminder"
  end
end
