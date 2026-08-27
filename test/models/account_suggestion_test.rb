require "test_helper"

class AccountSuggestionTest < ActiveSupport::TestCase
  test "excludes kinds the household already holds" do
    suggestions = AccountSuggestion.for(Products.wrap_all(Account.all))
    kinds = suggestions.map(&:kind)

    assert_not_includes kinds, "tfsa"
    assert_not_includes kinds, "rrsp"
    assert_includes kinds, "fhsa"
    assert_includes kinds, "resp"
  end

  test "returns the full catalog when nothing is held" do
    suggestions = AccountSuggestion.for([])
    assert_equal AccountSuggestion::CATALOG.map(&:kind), suggestions.map(&:kind)
  end
end
