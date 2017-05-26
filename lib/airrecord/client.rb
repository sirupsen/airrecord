require 'uri'

module Airrecord
  class Client
    attr_reader :api_key
    attr_writer :connection

    def initialize(api_key)
      @api_key = api_key
    end

    def connection
      @connection ||= Faraday.new(url: "https://api.airtable.com", headers: {
        "Authorization" => "Bearer #{api_key}",
        "X-API-VERSION" => "0.1.0",
      }) { |conn|
        conn.adapter :net_http_persistent
      }
    end

    def escape(*args)
      URI.escape(*args)
    end

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def handle_error(status, error)
      if error.is_a?(Hash)
        raise Error, "HTTP #{status}: #{error['error']["type"]}: #{error['error']['message']}"
      else
        raise Error, "HTTP #{status}: Communication error: #{error}"
      end
    end
  end
end
