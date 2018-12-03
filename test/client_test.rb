require 'test_helper'

class ClientTest < Minitest::Test
  def setup
    @stubs = Faraday::Adapter::Test::Stubs.new
    @client = Airrecord::Client.new("API_KEY").tap { |instance|
      instance.connection = Faraday.new { |builder|
        builder.adapter :test, @stubs
      }
    }
  end

  def test_client_connection_uses_net_http_persistent_by_default
    client = Airrecord::Client.new('not stubbed')
    adapter = client.connection.builder.handlers.last

    assert_equal(adapter, Faraday::Adapter::NetHttpPersistent)
  end

  def test_client_request_escapes_urls_correctly
    request = Airrecord::Client::Request.new(
      'mock client',
      "/v0/appdnc1gxGiuJIl2U/table name/rec3ksiISOB6cQmtg"
    )

    expected = "/v0/appdnc1gxGiuJIl2U/table%20name/rec3ksiISOB6cQmtg"
    actual = request.instance_variable_get(:@url)

    assert_equal expected, actual
  end

  def test_successful_get_request_returns_valid_json
    @stubs.get('/valid') { |env| [200, {}, { "hello" => "world" }.to_json] }
    response = @client.request('/valid')
    assert_equal(response["hello"], "world")
  end

  def test_successful_patch_request_returns_valid_json
    @stubs.patch('/id') { |env| [200, {}, { "hello" => "world" }.to_json] }
    response = @client.request('/id', method: 'patch')

    assert_equal(response["hello"], "world")
  end

  def test_successful_request_handles_malformed_json
    @stubs.delete('/invalid') { |env| [204, {}, ''] }

    assert @client.request('/invalid', method: :delete)
  end

  def test_unsuccessful_request_raises_error
    @stubs.get('/error') { |env| [422, {}, "Unprocessable"] }

    assert_raises(Airrecord::Error) { @client.request('/error') }
  end
end
