require 'securerandom'
require 'test_helper'

class Walrus < Airrecord::Table
  self.base_key = 'app1'
  self.table_name = 'walruses'
end

class TableTest < Minitest::Test
  def setup
    Airrecord.api_key = "key2"
    @table = Airrecord.table("key1", "app1", "table1")

    @stubs = Faraday::Adapter::Test::Stubs.new
    @table.client.connection = Faraday.new { |builder|
      builder.adapter :test, @stubs
    }

    stub_request([{"Name": "omg", "Notes": "hello world", " Something  else\n" => "hi"}, {"Name": "more", "Notes": "walrus"}])
  end

  def test_table_overrides_key
    assert_equal "key1", @table.api_key
  end

  def test_walrus_uses_default_key
    assert_equal "key2", Walrus.api_key
  end

  def test_retrieve_records
    assert_instance_of Array, @table.records
  end

  def test_different_clients_with_different_api_keys
    table1 = Airrecord.table("key1", "app1", "unknown")
    table2 = Airrecord.table("key2", "app2", "unknown")

    refute_equal table1.client, table2.client
  end

  def test_filter_records
    stub_request([{"Name": "yes"}, {"Name": "no"}])

    records = @table.records(filter: "Name")
    assert_equal "yes", records[0][:name]
  end

  def test_sort_records
    stub_request([{"Name": "a"}, {"Name": "b"}])

    records = @table.records(sort: { Name: 'asc' })
    assert_equal "a", records[0][:name]
    assert_equal "b", records[1][:name]
  end

  def test_view_records
    stub_request([{"Name": "a"}, {"Name": "a"}])

    records = @table.records(view: 'A')
    assert_equal "a", records[0][:name]
    assert_equal "a", records[1][:name]
  end

  def test_follow_pagination_by_default
    stub_request([{"Name": "1"}, {"Name": "2"}], offset: 'dasfuhiu')
    stub_request([{"Name": "3"}, {"Name": "4"}], offset: 'odjafio', clear: false)
    stub_request([{"Name": "5"}, {"Name": "6"}], clear: false)

    records = @table.records
    assert_equal 6, records.size
  end

  def test_dont_follow_pagination_if_disabled
    stub_request([{"Name": "1"}, {"Name": "2"}], offset: 'dasfuhiu')
    stub_request([{"Name": "3"}, {"Name": "4"}], offset: 'odjafio', clear: false)
    stub_request([{"Name": "5"}, {"Name": "6"}], clear: false)

    records = @table.records(paginate: false)
    assert_equal 2, records.size
  end

  def test_index_by_normalized_name
    assert_equal "omg", first_record[:name]
  end

  def test_index_by_column_name
    assert_equal "omg", first_record["Name"]
  end

  def test_cleans_bad_keys
    assert_equal "hi", first_record[:something_else]
  end

  def test_id
    assert_instance_of String, first_record.id
  end

  def test_created_at
    assert_instance_of Time, first_record.created_at
  end

  def test_error_response
    table = Airrecord.table("key1", "app1", "unknown")

    stub_error_request(type: "TABLE_NOT_FOUND", message: "Could not find table", table: table)

    assert_raises Airrecord::Error do
      table.records
    end
  end

  def test_change_value
    record = first_record
    record[:name] = "testest"
    assert_equal "testest", record[:name]
  end

  def test_change_value_on_column_name
    record = first_record
    record["Name"] = "testest"
    assert_equal "testest", record[:name]
  end

  def test_change_value_and_update
    record = first_record

    record[:name] = "new_name"
    stub_patch_request(record, ["Name"])

    assert record.save
  end

  def test_change_value_then_save_again_should_noop
    record = first_record

    record[:name] = "new_name"
    stub_patch_request(record, ["Name"])

    assert record.save
    assert record.save
  end

  def test_updates_fields_to_newest_values_after_update
    record = first_record

    record[:name] = "new_name"
    stub_patch_request(record, ["Name"], return_body: record.fields.merge("Notes" => "new animal"))

    assert record.save
    assert_equal "new_name", record[:name]
    assert_equal "new animal", record[:notes]
  end

  def test_update_failure
    record = first_record

    record[:name] = "new_name"
    stub_patch_request(record, ["Name"], return_body: { error: { type: "oh noes", message: 'yes' } }, status: 401)

    assert_raises Airrecord::Error do
      record.save
    end
  end

  def test_update_failure_then_succeed
    record = first_record

    record[:name] = "new_name"
    stub_patch_request(record, ["Name"], return_body: { error: { type: "oh noes", message: 'yes' } }, status: 401)

    assert_raises Airrecord::Error do
      record.save
    end

    stub_patch_request(record, ["Name"])
    assert record.save
  end

  def test_update_raises_if_new_record
    record = @table.new(Name: "omg")

    assert_raises Airrecord::Error do
      record.save
    end
  end

  def test_existing_record_is_not_new
    refute first_record.new_record?
  end

  def test_build_new_record
    record = @table.new(Name: "omg")

    refute record.id
    refute record.created_at
    assert record.new_record?
  end

  def test_create_new_record
    record = @table.new(Name: "omg")

    stub_post_request(record)

    assert record.create
  end

  def test_create_existing_record_fails
    record = @table.new(Name: "omg")

    stub_post_request(record)

    assert record.create

    assert_raises Airrecord::Error do
      record.create
    end
  end

  def test_create_handles_error
    record = @table.new(Name: "omg")

    stub_post_request(record, status: 401, return_body: { error: { type: "omg", message: "wow" }})

    assert_raises Airrecord::Error do
      record.create
    end
  end

  def test_find
    record = @table.new(Name: "walrus")

    stub_find_request(record, id: "iodfajsofja")

    record = @table.find("iodfajsofja")
    assert_equal "walrus", record[:name]
    assert_equal "iodfajsofja", record.id
  end

  def test_find_handles_error
    stub_find_request(nil, return_body: { error: { type: "not found", message: "not found" } }, id: "noep", status: 404)

    assert_raises Airrecord::Error do
      @table.find("noep")
    end
  end

  def test_destroy_new_record_fails
    record = @table.new(Name: "walrus")

    assert_raises Airrecord::Error do
      record.destroy
    end
  end

  def test_destroy_record
    record = first_record
    stub_delete_request(record.id)
    assert record.destroy
  end

  def test_fail_destroy_record
    record = first_record
    stub_delete_request(record.id, status: 404, response_body: { error: { type: "not found", message: "whatever" } }.to_json)

    assert_raises Airrecord::Error do
      record.destroy
    end
  end

  def test_error_handles_errors_without_body
    record = first_record

    stub_delete_request(record.id, status: 500)

    assert_raises Airrecord::Error do
      record.destroy
    end
  end

  def test_dates_are_type_casted
    stub_request([{"Name": "omg", "Created": Time.now.to_s}])

    record = first_record
    assert_instance_of Time, record[:created]
  end
end
