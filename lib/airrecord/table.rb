module Airrecord
  # TODO: This would be much simplified if we had a schema instead. Hopefully
  # one day Airtable will add this, but to simplify and crush the majority of
  # the bugs that hide in here (which would be related to the dynamic schema) we
  # may just query the first page and infer a schema from there that can be
  # overridden on the specific classes.
  #
  # Right now I bet there's a bunch of bugs around similar named column keys (in
  # terms of capitalization), it's inconsistent and non-obvious that `create`
  # doesn't use the same column keys as everything else.
  class Table
    class << self
      attr_accessor :base_key, :table_name, :api_key, :associations

      def client
        @@clients ||= {}
        @@clients[api_key] ||= Client.new(api_key)
      end

      def has_many(name, options)
        @associations ||= []
        @associations << {
          field: name.to_sym,
        }.merge(options)
      end

      def belongs_to(name, options)
        has_many(name, options.merge(single: true))
      end

      def api_key
        @api_key || Airrecord.api_key
      end

      def find(id)
        response = client.connection.get("/v0/#{base_key}/#{client.escape(table_name)}/#{id}")
        parsed_response = client.parse(response.body)

        if response.success?
          self.new(parsed_response["fields"], id: id)
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

        path = "/v0/#{base_key}/#{client.escape(table_name)}"
        response = client.connection.get(path, options)
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
      alias_method :all, :records
    end

    attr_reader :fields, :column_mappings, :id, :created_at, :updated_keys

    def initialize(fields, id: nil, created_at: nil)
      @id = id
      self.created_at = created_at
      self.fields = fields
    end

    def new_record?
      !id
    end

    def [](key)
      value = nil

      if fields[key]
        value = fields[key]
      elsif column_mappings[key]
        value = fields[column_mappings[key]]
      end

      if association = self.association(key)
        klass = Kernel.const_get(association[:class])
        associations = value.map { |id_or_obj|
          id_or_obj = id_or_obj.respond_to?(:id) ? id_or_obj.id : id_or_obj
          klass.find(id_or_obj)
        }
        return associations.first if association[:single]
        associations
      else
        type_cast(value)
      end
    end

    def []=(key, value)
      if fields[key]
        return if fields[key] == value # no-op
        @updated_keys << key
        fields[key] = value
      elsif column_mappings[key]
        return if fields[column_mappings[key]] == value # no-op
        @updated_keys << column_mappings[key]
        fields[column_mappings[key]] = value
      else
        @updated_keys << key
        fields[key] = value
      end
    end

    def create
      raise Error, "Record already exists (record has an id)" unless new_record?

      body = { fields: serializable_fields }.to_json
      response = client.connection.post("/v0/#{self.class.base_key}/#{client.escape(self.class.table_name)}", body, { 'Content-Type': 'application/json' })
      parsed_response = client.parse(response.body)

      if response.success?
        @id = parsed_response["id"]
        self.created_at = parsed_response["createdTime"]
        self.fields = parsed_response["fields"]
      else
        client.handle_error(response.status, parsed_response)
      end
    end

    def save
      raise Error, "Unable to save a new record" if new_record?

      return true if @updated_keys.empty?

      # To avoid trying to update computed fields we *always* use PATCH
      body = {
        fields: Hash[@updated_keys.map { |key|
          [key, fields[key]]
        }]
      }.to_json

      response = client.connection.patch("/v0/#{self.class.base_key}/#{client.escape(self.class.table_name)}/#{self.id}", body, { 'Content-Type': 'application/json' })
      parsed_response = client.parse(response.body)

      if response.success?
        self.fields = parsed_response
      else
        client.handle_error(response.status, parsed_response)
      end
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

    def serializable_fields(fields = self.fields)
      Hash[fields.map { |(key, value)|
        if association(key)
          value = [ value ] unless value.is_a?(Enumerable)
          assocs = value.map { |assoc|
            assoc.respond_to?(:id) ? assoc.id : assoc
          }               
          [key, assocs]
        else
          [key, value]
        end
        }]
    end
    
    def ==(other)
      self.class == other.class &&
        serializable_fields == other.serializable_fields
    end

    protected

    def association(key)
      if self.class.associations
        self.class.associations.find { |association|
          association[:column].to_s == column_mappings[key].to_s || association[:column].to_s == key.to_s
        }
      end
    end

    def fields=(fields)
      @updated_keys = []
      @column_mappings = Hash[fields.keys.map { |key| [underscore(key), key] }]
      @fields = fields
    end

    def self.underscore(key)
      key.to_s.strip.gsub(/\W+/, "_").downcase.to_sym
    end

    def underscore(key)
      self.class.underscore(key)
    end

    def created_at=(created_at)
      return unless created_at
      @created_at = Time.parse(created_at)
    end

    def client
      self.class.client
    end

    def type_cast(value)
      if value =~ /\d{4}-\d{2}-\d{2}/
        Time.parse(value + " UTC")
      else
        value
      end
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
