module Airrecord
  # The Airtable API expects arrays to be URL-encoded with indices.
  # Faraday doesn't encode arrays this way, but node's "qs" module does:
  # https://github.com/ljharb/qs#stringifying
  #
  # Airrecord::QueryString makes the qs format available to Faraday
  module QueryString
    module_function

    def encode(params)
      params.map { |key, val| Encodings[val].call(key, val) }.join('&')
    end

    def decode(query)
      Faraday::NestedParamsEncoder.decode(query)
    end

    module Encodings
      module_function

      def [](value)
        encoding = "encode_#{value.class}".downcase.to_sym
        respond_to?(encoding) ? method(encoding) : encode_default
      end

      def encode_default
        ->(key, value) { "#{key}=#{value}" }
      end

      def encode_array(prefix, array)
        array.each_with_index.map do |value, index|
          Encodings[value].call("#{prefix}[#{index}]", value)
        end
      end

      def encode_hash(prefix, hash)
        hash.map do |key, value|
          Encodings[value].call("#{prefix}[#{key}]", value)
        end
      end
    end
  end
end
