require 'test_helper'

class QueryStringTest < Minitest::Test
  def setup
    @params = { maxRecords: 50, view: "Master" }
    @query = "maxRecords=3&pageSize=1&sort%5B0%5D%5Bfield%5D=Quality&sort%5B0%5D%5Bdirection%5D=asc"
    @qs = Airrecord::QueryString
  end

  def test_encoding_simple_params_matches_faraday
    expected = Faraday::NestedParamsEncoder.encode(@params)
    result = @qs.encode(@params)

    assert_equal(result, expected)
  end

  def test_decode_matches_faraday
    assert_equal(
      Faraday::NestedParamsEncoder.decode(@query),
      @qs.decode(@query),
    )
  end

  def test_encoding_arrays_uses_indices
    params = @params.merge(fields: %w[Quality Price])

    expected = "maxRecords=50&view=Master&fields%5B0%5D=Quality&fields%5B1%5D=Price"
    result = @qs.encode(params)

    assert_equal(result, expected)
  end

  def test_encoding_arrays_of_objects
    params = { sort: [
      { field: 'Quality', direction: 'desc' },
      { field: 'Price', direction: 'asc' }
    ]}

    expected = "sort%5B0%5D%5Bfield%5D=Quality&sort%5B0%5D%5Bdirection%5D=desc&sort%5B1%5D%5Bfield%5D=Price&sort%5B1%5D%5Bdirection%5D=asc"
    result = @qs.encode(params)

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
    result = Faraday::NestedParamsEncoder.decode(@qs.encode(params))

    assert_equal(result, expected)
  end

  def test_escaping_one_string
    assert_equal(@qs.escape("test string"), "test%20string")
  end

  def test_escaping_many_strings
    strings = ['test', 'string']
    assert_equal(@qs.escape(*strings), 'teststring')
  end
end
