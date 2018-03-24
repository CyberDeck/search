require 'test_helper'

class Search::Dsl::Test < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, Search
    assert_kind_of Module, Search::Dsl
  end
end
