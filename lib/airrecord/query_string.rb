require 'erb'

module Airrecord
  # Airtable expects that arrays in query strings be encoded with indices.
  # Faraday follows Rack conventions and encodes arrays _without_ indices.
  #
  # Airrecord::QueryString is a Faraday-compliant params_encoder that follows
  # the Airtable spec.
  module QueryString
    def self.encode(params)
      params.map { |key, val| Encodings[val].call(key, val) }.join('&')
    end

    def self.decode(query)
      Faraday::NestedParamsEncoder.decode(query)
    end

    def self.escape(*query)
      query.map { |qs| ERB::Util.url_encode(qs) }.join('')
    end

    module Encodings
      def self.[](value)
        TYPES.fetch(value.class, DEFAULT)
      end

      TYPES = {
        Array => lambda do |prefix, array|
          array.each_with_index.map do |value, index|
            self[value].call("#{prefix}[#{index}]", value)
          end
        end,
        Hash => lambda do |prefix, hash|
          hash.map do |key, value|
            self[value].call("#{prefix}[#{key}]", value)
          end
        end
      }.freeze

      DEFAULT = lambda do |key, value|
        "#{QueryString.escape(key)}=#{QueryString.escape(value)}"
      end
    end
  end
end
