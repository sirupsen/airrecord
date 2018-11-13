require 'test_helper'
require 'airrecord/faraday_rate_limiter'

class FaradayRateLimiterTest < Minitest::Test
  def setup
    @stubs = Faraday::Adapter::Test::Stubs.new
    @rps = 5
    @sleeps = []
    @connection = Faraday.new { |builder|
      builder.request :airrecord_rate_limiter,
        requests_per_second: @rps,
        sleeper: ->(s) { @sleeps << s }

      builder.adapter :test, @stubs
    }

    @stubs.get("/whatever") do |env|
      [200, {}, "walrus"]
    end
  end

  def teardown
    @connection.app.clear
  end

  def test_passes_through_single_request
    @connection.get("/whatever")
    assert_predicate @sleeps, :empty?
  end

  def test_sleeps_on_the_rps_plus_oneth_request
    @rps.times do
      @connection.get("/whatever")
    end

    assert_predicate @sleeps, :empty?

    @connection.get("/whatever")

    assert_equal 1, @sleeps.size
    assert @sleeps.first > 0.9
  end
end
