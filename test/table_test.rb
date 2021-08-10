require 'securerandom'
require 'test_helper'

class Walrus < Airrecord::Table
  self.base_key = 'app1'
  self.table_name = 'walruses'

  has_many :feet, class: 'Foot', column: 'Feet'
end

class Foot < Airrecord::Table
  self.base_key = 'app1'
  self.table_name = 'foot'

  belongs_to :walrus, class: 'Walrus', column: 'Walrus'
end

class TableTest < Minitest::Test
  def setup
    Airrecord.api_key = "key2"
    @table = Airrecord.table("key1", "app1", "table1")

    @stubs = Faraday::Adapter::Test::Stubs.new
    @table.client.connection = Faraday.new { |builder|
      builder.adapter :test, @stubs
    }

    stub_request([{"Name" => "omg", "Notes" => "hello world"}, {"Name" => "more", "Notes" => "walrus"}])
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
    stub_request([{"Name" => "yes"}, {"Name" => "no"}])

    records = @table.records(filter: "Name")
    assert_equal "yes", records[0]["Name"]
  end

  def test_sort_records
    stub_request([{"Name" => "a"}, {"Name" => "b"}])

    records = @table.records(sort: { "Name" => 'asc' })
    assert_equal "a", records[0]["Name"]
    assert_equal "b", records[1]["Name"]
  end

  def test_view_records
    stub_request([{"Name" => "a"}, {"Name" => "a"}])

    records = @table.records(view: 'A')
    assert_equal "a", records[0]["Name"]
    assert_equal "a", records[1]["Name"]
  end

  def test_follow_pagination_by_default
    stub_request([{"Name" => "1"}, {"Name" => "2"}], offset: 'dasfuhiu')
    stub_request([{"Name" => "3"}, {"Name" => "4"}], offset: 'odjafio', clear: false)
    stub_request([{"Name" => "5"}, {"Name" => "6"}], clear: false)

    records = @table.records
    assert_equal 6, records.size
  end

  def test_dont_follow_pagination_if_disabled
    stub_request([{"Name" => "1"}, {"Name" => "2"}], offset: 'dasfuhiu')
    stub_request([{"Name" => "3"}, {"Name" => "4"}], offset: 'odjafio', clear: false)
    stub_request([{"Name" => "5"}, {"Name" => "6"}], clear: false)

    records = @table.records(paginate: false)
    assert_equal 2, records.size
  end

  def test_index_by_normalized_name
    assert_equal "omg", first_record["Name"]
  end

  def test_index_by_column_name
    assert_equal "omg", first_record["Name"]
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
    record["Name"] = "testest"
    assert_equal "testest", record["Name"]
  end

  def test_change_value_on_column_name
    record = first_record
    record["Name"] = "testest"
    assert_equal "testest", record["Name"]
  end

  def test_change_value_and_update
    record = first_record

    record["Name"] = "new_name"
    stub_patch_request(record, ["Name"])

    assert record.save
  end

  def test_change_value_and_update_with_typecast_enabled
    record = first_record

    record["Name"] = "new_name"
    stub_patch_request(record, ["Name"], options: {typecast: true})

    assert record.save(typecast: true)
  end

  def test_change_value_then_save_again_should_noop
    record = first_record

    record["Name"] = "new_name"
    stub_patch_request(record, ["Name"])

    assert record.save
    assert record.save
  end

  def test_change_value_with_symbol_raises_error
    assert_raises Airrecord::Error do
      first_record[:Name] = "new_name"
    end
  end

  def test_access_value_with_symbol_raises_error
    assert_raises Airrecord::Error do
      first_record[:Name]
    end
  end

  def test_updates_fields_to_newest_values_after_update
    record = first_record

    record["Name"] = "new_name"
    stub_patch_request(record, ["Name"], return_body: { fields: record.fields.merge("Notes" => "new animal") })

    assert record.save
    assert_equal "new_name", record["Name"]
    assert_equal "new animal", record["Notes"]
  end

  def test_update_failure
    record = first_record

    record["Name"] = "new_name"
    stub_patch_request(record, ["Name"], return_body: { error: { type: "oh noes", message: 'yes' } }, status: 401)

    assert_raises Airrecord::Error do
      record.save
    end
  end

  def test_update_failure_then_succeed
    record = first_record

    record["Name"] = "new_name"
    stub_patch_request(record, ["Name"], return_body: { error: { type: "oh noes", message: 'yes' } }, status: 401)

    assert_raises Airrecord::Error do
      record.save
    end

    stub_patch_request(record, ["Name"])
    assert record.save
  end

  def test_update_creates_if_new_record
    record = @table.new("Name" => "omg")

    stub_post_request(record)

    assert record.save
  end

  def test_existing_record_is_not_new
    refute first_record.new_record?
  end

  def test_build_new_record
    record = @table.new("Name" => "omg")

    refute record.id
    refute record.created_at
    assert record.new_record?
  end

  def test_create_new_record
    record = @table.new("Name" => "omg")

    stub_post_request(record)

    assert record.create
  end

  def test_create_new_record_with_typecast_enabled
    record = @table.new("Name" => "omg")

    stub_post_request(record, options: {typecast: true})

    assert record.create(typecast: true)
  end

  def test_create_existing_record_fails
    record = @table.new("Name" => "omg")

    stub_post_request(record)

    assert record.create

    assert_raises Airrecord::Error do
      record.create
    end
  end

  def test_create_handles_error
    record = @table.new("Name" => "omg")

    stub_post_request(record, status: 401, return_body: { error: { type: "omg", message: "wow" }})

    assert_raises Airrecord::Error do
      record.create
    end
  end

  def test_class_level_create
    record = @table.new("Name" => "omg")

    stub_post_request(record)

    record = @table.create(record.fields)
    assert record.id
  end

  def test_class_level_create_with_typecast_enabled
    record = @table.new("Name" => "omg")

    stub_post_request(record, options: {typecast: true})

    record = @table.create(record.fields, typecast: true)
    assert record.id
  end

  def test_class_level_create_handles_error
    record = @table.new("Name" => "omg")

    stub_post_request(record, status: 401, return_body: { error: { type: "omg", message: "wow" }})

    assert_raises Airrecord::Error do
      @table.create record.fields
    end
  end

  def test_class_level_batch_create_new_record
    records = [{ "Name" => "Name1" }, { "Name" => "Name2" }, { "Name" => "Name3" }]

    request_body_mock = {
      records: [{ fields: { "Name" => "Name1" } }, { fields: { "Name" => "Name2" } }, { fields: { "Name" => "Name3" } }]
    }

    return_body_mock ||= { records: [
      { id: SecureRandom.hex(16), "Name" => "Name1", createdTime: Time.now },
      { id: SecureRandom.hex(16), "Name" => "Name2", createdTime: Time.now },
      { id: SecureRandom.hex(16), "Name" => "Name3", createdTime: Time.now }
    ] }

    stub_post_request(records, request_body: request_body_mock, return_body: return_body_mock)
    record = @table.batch_create(records)
    assert_equal true, record
  end

  def test_class_level_batch_create_handles_error
    records = [{ "Name" => "Name1" }, { "Name" => "Name2" }, { "Name" => "Name3" }]

    request_body_mock = {
      records: [{ fields: { "Name" => "Name1" } }, { fields: { "Name" => "Name2" } }, { fields: { "Name" => "Name3" } }]
    }

    stub_post_request(records, status: 401, request_body: request_body_mock, return_body: { error: { type: "went", message: "wrong" } })

    assert_raises Airrecord::Error do
      @table.batch_create(records)
    end
  end

  def test_class_level_batch_create_too_many_chunks_error
    records = Array.new(60, 0xF)

    request_body_mock = {
      records: [{ fields: { "Name" => "Name1" } }, { fields: { "Name" => "Name2" } }, { fields: { "Name" => "Name3" } }]
    }

    stub_post_request(records, status: 200, request_body: request_body_mock, return_body: {})

    assert_raises Airrecord::Error do
      @table.batch_create(records)
    end
  end

  def test_class_level_batch_limit_exceeds_max
    mock = MiniTest::Mock.new
    mock.expect(:warn, nil, ['Airreccord: We have set the value to the maximum batch size allowed, 10.'])

    @table.stub :warn, -> (arg) { mock.warn arg } do
      @table.batch_limit = (50)
    end

    assert_equal 10, @table.batch_limit
    assert mock.verify
  end

  def test_find
    record = @table.new("Name" => "walrus")

    stub_find_request(record, id: "iodfajsofja")

    record = @table.find("iodfajsofja")
    assert_equal "walrus", record["Name"]
    assert_equal "iodfajsofja", record.id
    assert_instance_of Time, record.created_at
  end

  def test_find_handles_error
    stub_find_request(nil, return_body: { error: { type: "not found", message: "not found" } }, id: "noep", status: 404)

    assert_raises Airrecord::Error do
      @table.find("noep")
    end
  end

  def test_find_many
    ids = %w[rec1 rec2 rec3]
    assert_instance_of Array, @table.find_many(ids)
  end

  def test_find_many_makes_no_network_call_when_ids_are_empty
    stub_request([], status: 500)

    assert_equal([], @table.find_many([]))
  end

  def test_destroy_new_record_fails
    record = @table.new("Name" => "walrus")

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

  def test_dates_are_not_type_casted
    stub_request([{"Name" => "omg", "Created" => Time.now.to_s}])

    record = first_record
    assert_instance_of String, record["Created"]
  end

  def test_comparison
    alpha = @table.new("Name" => "Name", "Created" => Time.at(0))
    beta = @table.new("Name" => "Name", "Created" => Time.at(0))

    assert_equal alpha, beta
  end

  def test_comparison_different_classes
    alpha = @table.new("Name" => "Name", "Created" => Time.at(0))
    beta = Walrus.new("Name" => "Name", "Created" => Time.at(0))

    refute_equal alpha, beta
  end

  def test_association_accepts_non_enumerable
    walrus = Walrus.new("Name" => "Wally")
    foot = Foot.new("Name" => "FrontRight", "walrus" => walrus)

    foot.serializable_fields
  end

  def test_dont_update_if_equal
    walrus = Walrus.new("Name" => "Wally")
    walrus["Name"] = "Wally"
    assert walrus.updated_keys.empty?
  end

  def test_equivalent_records_are_eql?
    walrus1 = Walrus.new("Name" => "Wally")
    walrus2 = Walrus.new("Name" => "Wally")

    assert walrus1.eql? walrus2
  end

  def test_non_equivalent_records_fail_eql?
    walrus1 = Walrus.new("Name" => "Wally")
    walrus2 = Walrus.new("Name" => "Wally2")

    assert !walrus1.eql?(walrus2)
  end

  def test_equivalent_hash_equality
    walrus1 = Walrus.new("Name" => "Wally")
    walrus2 = Walrus.new("Name" => "Wally")

    assert_equal walrus1.hash, walrus2.hash
  end

  def test_non_equivalent_hash_inequality
    walrus1 = Walrus.new("Name" => "Wally")
    walrus2 = Walrus.new("Name" => "Wally2")

    assert walrus1.hash != walrus2.hash
  end

  def test_complex_arguments
    mock_time = Time.now.to_s
    mock_id = 1

    walrus = Walrus.new({"Name" => "Wally"}, created_at: mock_time, id: mock_id)
    assert_equal mock_time, walrus.created_at.to_s
    assert_equal mock_id, walrus.id
    assert_equal "Wally", walrus["Name"]

    walrus = Walrus.new("Name" => "Wally", created_at: mock_time, id: mock_id)
    assert_equal "", walrus.created_at.to_s
    assert_nil walrus.id
    assert_equal "Wally", walrus["Name"]

    walrus = Walrus.new({"Name" => "Wally", created_at: mock_time, id: mock_id})
    assert_equal "", walrus.created_at.to_s
    assert_nil walrus.id
    assert_nil walrus["id"]
    assert_nil walrus["created_at"]
    assert_equal "Wally", walrus["Name"]
  end
end
