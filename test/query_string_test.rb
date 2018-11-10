require 'test_helper'

class QueryStringTest < Minitest::Test
  def setup
    @params = { maxRecords: 50, view: "Master" }
  end

  def test_encoding_simple_params_matches_faraday
    expected = Faraday::NestedParamsEncoder.encode(@params)
    result = Airrecord::QueryString.encode(@params)

    assert_equal(result, expected)
  end

  def test_encoding_arrays_uses_indices
    params = @params.merge(fields: %w[Quality Price])

    expected = "maxRecords=50&view=Master&fields[0]=Quality&fields[1]=Price"
    result = Airrecord::QueryString.encode(params)

    assert_equal(result, expected)
  end

  def test_encoding_arrays_of_objects
    params = { sort: [
      { field: 'Quality', direction: 'desc' },
      { field: 'Price', direction: 'asc' }
    ]}

    expected = 'sort[0][field]=Quality&sort[0][direction]=desc&sort[1][field]=Price&sort[1][direction]=asc'
    result = Airrecord::QueryString.encode(params)

    assert_equal(result, expected)
  end

  def test_params_fuzzing
    params = {
      "an explicit nil" => nil,
      horror: [1, 2, [{ mic: "check" }, { one: "two" }]],
      view: "A name with spaces",
    }

    expected = {
      "an explicit nil" => "",
      "horror" => ["1", "2", [{ "mic" => "check" }, { "one" => "two" }]],
      "view" => "A name with spaces",
    }
    result = Faraday::NestedParamsEncoder.decode(
      Airrecord::QueryString.encode(params)
    )

    assert_equal(result, expected)
  end
end
