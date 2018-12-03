require 'uri'
require_relative 'query_string'
require_relative 'faraday_rate_limiter'

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
          "X-API-VERSION" => "0.1.0",
        },
        request: { params_encoder: Airrecord::QueryString },
      ) { |conn|
        if Airrecord.throttle?
          conn.request :airrecord_rate_limiter, requests_per_second: AIRTABLE_RPS_LIMIT
        end
        conn.adapter :net_http_persistent
      }
    end

    # TODO: remove in v2
    def escape(*args)
      QueryString.escape(*args)
    end

    # TODO: remove in v2
    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    # TODO: remove in v2
    def handle_error(status, error)
      if error.is_a?(Hash)
        raise Error, "HTTP #{status}: #{error['error']["type"]}: #{error['error']['message']}"
      else
        raise Error, "HTTP #{status}: Communication error: #{error}"
      end
    end

    def request(url, options = {})
      Request.new(connection, url, options).call
    end

    class Request
      DEFAULTS = {
        method: :get,
        headers: { 'Content-Type' => 'application/json' },
      }.freeze

      def initialize(connection, url, options = {})
        @connection = connection
        @url = url.split('/').map { |str| QueryString.escape(str) }.join('/')
        @options = DEFAULTS.merge(options)
      end

      def call
        response.success? ? data : handle_error
      end

      private

      def response
        @response ||= @connection.run_request(
          @options[:method].to_sym,
          @url,
          @options[:body],
          @options[:headers],
          &method(:params)
        )
      end

      def params(req)
        req.params.update(@options[:params]) if @options[:params]
      end

      def data
        @data ||= JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end

      def handle_error
        prefix = "HTTP #{response.status}"
        suffix =
          if data.is_a?(Hash)
            "#{data['error']['type']}: #{data['error']['message']}"
          else
            "Communication error: #{data}"
          end
        raise Error, "#{prefix}: #{suffix}"
      end
    end
  end
end
