require "test_helper"

class PortfolioMcpTest < ActiveSupport::TestCase
  setup do
    @mcp = PortfolioMcp.new
  end

  test "lists read-only tools" do
    names = @mcp.tools.map(&:name)
    assert_includes names, "list_accounts"
    assert_includes names, "get_account_values"
    assert_includes names, "net_worth"
    assert_includes names, "allocation"
  end

  test "list_accounts returns fixture accounts" do
    result = @mcp.call("list_accounts")
    names = result.map { |row| row[:name] }

    assert_includes names, "Managed TFSA"
    assert_includes names, "Home mortgage"
    assert_includes names, "Aeroplan Visa Infinite"
  end

  test "get_account_values returns chronological snapshots" do
    result = @mcp.call("get_account_values", { "account_id" => accounts(:managed_tfsa).id })
    dates = result[:values].map { |v| v[:recorded_on] }

    assert_equal %w[2026-05-01 2026-06-01], dates
  end

  test "net_worth matches portfolio math" do
    result = @mcp.call("net_worth")
    assert_in_delta(-274_500.0, result[:net_worth], 0.01)
    assert result[:needs_check_in]
  end

  test "allocation excludes liabilities from asset slices" do
    result = @mcp.call("allocation")
    kinds = result[:slices].map { |s| s[:kind] }

    assert_includes kinds, "tfsa"
    assert_not_includes kinds, "liability"
    assert_not_includes kinds, "credit_card"
  end

  test "unknown tool returns an error payload" do
    result = @mcp.call("drop_tables")
    assert_match(/Unknown tool/, result[:error])
  end
end
