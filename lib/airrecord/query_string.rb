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

    module Encodings
      def self.[](value)
        TYPES.fetch(value.class, DEFAULT)
      end

      TYPES = {
        Array => lambda { |prefix, array|
          array.each_with_index.map do |value, index|
            self[value].call("#{prefix}[#{index}]", value)
          end
        },
        Hash => lambda { |prefix, hash|
          hash.map do |key, value|
            self[value].call("#{prefix}[#{key}]", value)
          end
        },
      }.freeze

      DEFAULT = ->(key, value) { "#{key}=#{value}" }.freeze
    end
  end
end
