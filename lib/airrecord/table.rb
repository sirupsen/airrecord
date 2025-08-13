require 'rubygems' # For Gem::Version

module Airrecord
  class Table
    class << self
      attr_accessor :base_key, :table_name
      attr_writer :api_key

      def client
        @@clients ||= {}
        @@clients[api_key] ||= Client.new(api_key)
      end

      def api_key
        defined?(@api_key) ? @api_key : Airrecord.api_key
      end

      def has_many(method_name, options)
        define_method(method_name.to_sym) do
          # Get association ids in reverse order, because Airtable's UI and API
          # sort associations in opposite directions. We want to match the UI.
          ids = (self[options.fetch(:column)] || []).reverse
          table = Kernel.const_get(options.fetch(:class))
          return table.find_many(ids) unless options[:single]

          (id = ids.first) ? table.find(id) : nil
        end

        define_method("#{method_name}=".to_sym) do |value|
          self[options.fetch(:column)] = Array(value).map(&:id).reverse
        end
      end

      def belongs_to(method_name, options)
        has_many(method_name, options.merge(single: true))
      end

      alias has_one belongs_to

      def find(id)
        response = client.connection.get("/v0/#{base_key}/#{client.escape(table_name)}/#{id}")
        parsed_response = client.parse(response.body)

        if response.success?
          self.new(parsed_response["fields"], id: id, created_at: parsed_response["createdTime"])
        else
          client.handle_error(response.status, parsed_response)
        end
      end

      def find_or_create(id, fields, options = {})
        find(id) || create(fields, options)
      end

      def find_many(ids)
        return [] if ids.empty?

        or_args = ids.map { |id| "RECORD_ID() = '#{id}'"}.join(',')
        formula = "OR(#{or_args})"
        records(filter: formula).sort_by { |record| or_args.index(record.id) }
      end

      def update(id, update_hash = {}, options = {})
        # To avoid trying to update computed fields we *always* use PATCH
        body = {
          fields: update_hash,
          **options
        }.to_json

        response = client.connection.patch("/v0/#{base_key}/#{client.escape(table_name)}/#{id}", body, { 'Content-Type' => 'application/json' })
        parsed_response = client.parse(response.body)

        if response.success?
          parsed_response["fields"]
        else
          client.handle_error(response.status, parsed_response)
        end
      end

      # @params {Array[Hash]} update_records
      # @params {Hash}        options
      # @return {boolean}     updated records
      # 
      # update_records example: [{ fields: { TEST: 'Some Value'}, id: <record_id> }, ...]
      def bulk_update(update_records = [], options = {})
        raise "Allowed only 10 records in the bulk." if update_records.size > 10

        body = { records: update_records, **options }.to_json

        response = client.connection.patch("/v0/#{base_key}/#{client.escape(table_name)}", body,
                                          { 'Content-Type' => 'application/json' })

        parsed_response = parse(response.body)

        if response.success?
          parsed_response['records'].map do |record|
            new(record['fields'], id: record['id'], created_at: record['createdTime'])
          end
        else
          client.handle_error(response.status, parsed_response)
        end
      end

      def create(fields, options = {})
        new(fields).tap { |record| record.save(options) }
      end

      # @params {Array[Hash]} create_records
      # @params {Hash}        options
      # @return {boolean}     updated records
      # 
      # create_records example: [{ fields: { TEST: 'Some Value'}}, ...]
      def bulk_create(create_records = [], options = {})
      raise "Allowed only 10 records in the bulk." if create_records.size > 10

        body = { records: create_records, **options }.to_json

        response = client.connection.post("/v0/#{base_key}/#{client.escape(table_name)}", body,
                                          { 'Content-Type' => 'application/json' })

        parsed_response = parse(response.body)

        if response.success?
          parsed_response['records'].map do |record|
            new(record['fields'], id: record['id'], created_at: record['createdTime'])
          end
        else
          client.handle_error(response.status, parsed_response)
        end
      end

      # @params { Array[Record_ID] }                                   ids
      # @params { Hash }                                               options
      # @return { Array[{'deleted':boolean, 'id':string}] | boolean }  success statatus
      def bulk_delete(ids)
        raise "Allowed only 10 records in the bulk." if ids.size > 10

        query = ids.map { |id| "#{CGI.escape('records[]')}=#{id}" }.join('&')

        response = client.connection.delete("/v0/#{base_key}/#{client.escape(table_name)}?#{query}",
                                            { 'Content-Type' => 'application/json' })

        parsed_response = parse(response.body)

        if response.success?
          parsed_response['records']
        else
          client.handle_error(response.status, parsed_response)
        end
      end

      def records(filter: nil, sort: nil, view: nil, offset: nil, paginate: true, fields: nil, max_records: nil, page_size: nil)
        options = {}
        options[:filterByFormula] = filter if filter

        if sort
          options[:sort] = sort.map { |field, direction|
            { field: field.to_s, direction: direction }
          }
        end

        options[:view] = view if view
        options[:offset] = offset if offset
        options[:fields] = fields if fields
        options[:maxRecords] = max_records if max_records
        options[:pageSize] = page_size if page_size

        path = "/v0/#{base_key}/#{client.escape(table_name)}/listRecords"
        response = client.connection.post(path, options.to_json, { 'Content-Type' => 'application/json' })
        parsed_response = client.parse(response.body)

        if response.success?
          records = parsed_response["records"]
          records = records.map { |record|
            self.new(record["fields"], id: record["id"], created_at: record["createdTime"])
          }

          if paginate && parsed_response["offset"]
            records.concat(records(
              filter: filter,
              sort: sort,
              view: view,
              paginate: paginate,
              fields: fields,
              offset: parsed_response["offset"],
              max_records: max_records,
              page_size: page_size,
            ))
          end

          records
        else
          client.handle_error(response.status, parsed_response)
        end
      end
      alias all records

      def count
        records(fields: []).count
      end
    end

    attr_reader :fields, :id, :created_at, :updated_keys

    # This is an awkward definition for Ruby 3 to remain backwards compatible.
    # It's easier to read by reading the 2.x definition below.
    if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.0.0")
      def initialize(*one, **two)
        @id = one.first && two.delete(:id)
        self.created_at = one.first && two.delete(:created_at)
        self.fields = one.first || two
      end
    else
      def initialize(fields, id: nil, created_at: nil)
        @id = id
        self.created_at = created_at
        self.fields = fields
      end
    end

    def new_record?
      !id
    end

    def [](key)
      validate_key(key)
      fields[key]
    end

    def []=(key, value)
      validate_key(key)
      return if fields[key] == value # no-op

      @updated_keys << key
      fields[key] = value
    end

    def create(options = {})
      raise Error, "Record already exists (record has an id)" unless new_record?

      body = {
        fields: serializable_fields,
        **options
      }.to_json

      response = client.connection.post("/v0/#{self.class.base_key}/#{client.escape(self.class.table_name)}", body, { 'Content-Type' => 'application/json' })
      parsed_response = client.parse(response.body)

      if response.success?
        @id = parsed_response["id"]
        self.created_at = parsed_response["createdTime"]
        self.fields = parsed_response["fields"]
      else
        client.handle_error(response.status, parsed_response)
      end
    end

    def save(options = {})
      return create(options) if new_record?
      return true if @updated_keys.empty?

      update_hash = Hash[@updated_keys.map { |key|
        [key, fields[key]]
      }]

      self.fields = self.class.update(self.id, update_hash, options)
    end

    def destroy
      raise Error, "Unable to destroy new record" if new_record?

      response = client.connection.delete("/v0/#{self.class.base_key}/#{client.escape(self.class.table_name)}/#{self.id}")
      parsed_response = client.parse(response.body)

      if response.success?
        true
      else
        client.handle_error(response.status, parsed_response)
      end
    end

    def serializable_fields
      fields
    end

    def ==(other)
      self.class == other.class &&
        serializable_fields == other.serializable_fields
    end
    alias eql? ==

    def hash
      serializable_fields.hash
    end

    protected

    def fields=(fields)
      @updated_keys = []
      @fields = fields
    end

    def created_at=(created_at)
      return unless created_at

      @created_at = Time.parse(created_at)
    end

    def client
      self.class.client
    end

    def validate_key(key)
      return true unless key.is_a?(Symbol)

      raise(Error, [
        "Airrecord 1.0 dropped support for Symbols as field names.",
        "Please use the raw field name, a String, instead.",
        "You might try: record['#{key.to_s.tr('_', ' ')}']"
      ].join("\n"))
    end
  end

  def self.table(api_key, base_key, table_name)
    Class.new(Table) do |klass|
      klass.table_name = table_name
      klass.api_key = api_key
      klass.base_key = base_key
    end
  end
end
