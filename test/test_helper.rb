$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'airrecord'
require 'byebug'
require 'securerandom'
require 'minitest/autorun'

class Minitest::Test
  def stub_delete_request(id, table: @table, status: 202, response_body: "")
    @stubs.delete("/v0/#{@table.base_key}/#{@table.table_name}/#{id}") do |env|
      [status, {}, response_body]
    end
  end

  def stub_post_request(record, table: @table, status: 200, headers: {}, options: {}, return_body: nil, request_body: nil)
    return_body ||= {
      id: SecureRandom.hex(16),
      fields: record.serializable_fields,
      createdTime: Time.now,
    }
    return_body = return_body.to_json

    request_body ||= {
      fields: record.serializable_fields,
      **options,
    }
    request_body = request_body.to_json

    @stubs.post("/v0/#{table.base_key}/#{table.table_name}", request_body) do |env|
      [status, headers, return_body]
    end
  end

  def stub_patch_request(record, updated_keys, table: @table, status: 200, headers: {}, options: {}, return_body: nil)
    return_body ||= { fields: record.fields }
    return_body = return_body.to_json

    request_body = {
      fields: Hash[updated_keys.map { |key|
        [key, record.fields[key]]
      }],
      **options,
    }.to_json
    @stubs.patch("/v0/#{@table.base_key}/#{@table.table_name}/#{record.id}", request_body) do |env|
      [status, headers, return_body]
    end
  end

  # TODO: Problem, can't stub on params.
  def stub_request(records, table: @table, status: 200, headers: {}, offset: nil, clear: true)
    @stubs.instance_variable_set(:@stack, {}) if clear

    body = {
      records: records.map { |record|
        {
          id: record["id"] || SecureRandom.hex(16),
          fields: record,
          createdTime: Time.now,
        }
      },
      offset: offset,
    }.to_json

    @stubs.get("/v0/#{table.base_key}/#{table.table_name}") do |env|
      [status, headers, body]
    end
  end

  def stub_find_request(record = nil, table: @table, status: 200, headers: {}, return_body: nil, id: nil)
    return_body ||= {
      id: id,
      fields: record.fields,
      createdTime: Time.now,
    }
    return_body = return_body.to_json

    id ||= record.id

    @stubs.get("/v0/#{table.base_key}/#{table.table_name}/#{id}") do |env|
      [status, headers, return_body]
    end
  end

  def stub_error_request(type:, message:, status: 401, headers: {}, table: @table)
    body = {
      error: {
        type: type,
        message: message,
      }
    }.to_json

    @stubs.get("/v0/#{table.base_key}/#{table.table_name}") do |env|
      [status, headers, body]
    end
  end

  def first_record
    @table.records.first
  end
end
