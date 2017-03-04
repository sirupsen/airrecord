require 'test_helper'

class AirrecordTest < Minitest::Test
  def test_set_api_key
    Airrecord.api_key = "walrus"
    assert_equal "walrus", Airrecord.api_key
  end
end
