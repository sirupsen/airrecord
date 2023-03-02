require_relative 'faraday_rate_limiter'
require 'erb'

module Airrecord
  class Client
    attr_reader :api_key
    attr_writer :connection

    # Per Airtable's documentation you will get throttled for 30 seconds if you
    # issue more than 5 requests per second. Airrecord is a good citizen.
    AIRTABLE_RPS_LIMIT = 5

    def initialize(api_key)
      @api_key = api_key
    end

    def connection
      @connection ||= Faraday.new(
        url: "https://api.airtable.com",
        headers: {
          "Authorization" => "Bearer #{api_key}",
          "User-Agent"    => "Airrecord/#{Airrecord::VERSION}",
        },
      ) do |conn|
        if Airrecord.throttle?
          conn.request :airrecord_rate_limiter, requests_per_second: AIRTABLE_RPS_LIMIT
        end
        conn.adapter :net_http_persistent
      end
    end

    def escape(*args) 
      ERB::Util.url_encode(*args)
    end

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def handle_error(status, error)
      if error.is_a?(Hash) && error['error']
        raise Error, "HTTP #{status}: #{error['error']['type']}: #{error['error']['message']}"
      else
        raise Error, "HTTP #{status}: Communication error: #{error}"
      end
    end
  end
end
