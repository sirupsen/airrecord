require 'test_helper'

class RelationTest < MiniTest::Test
  def setup
    @table = Airrecord.table("key1", "app1", "table1")
    @table.define_singleton_method(:records) { |options| options }
  end

  def test_blank_relation_produces_empty_params
    assert_equal({}, @table.where.to_h)
  end

  def test_where_with_one_key_makes_valid_filter
    expected = { filter: "AND({Rank} = 'Captain')" }
    actual = @table.where("Rank" => "Captain").to_h

    assert_equal expected, actual
  end

  def test_where_with_many_keys_makes_valid_filter
    expected = { filter: "AND({Rank} = 'Captain', {Name} = 'Spock')" }
    actual = @table.where("Rank" => "Captain", "Name" => "Spock").to_h

    assert_equal expected, actual
  end

  def test_where_merges_multiple_calls_into_valid_filter
    expected = { filter: "AND({Rank} = 'Captain', {Name} = 'Spock')" }
    actual = @table.where("Rank" => "Captain").where("Name" => "Spock").to_h

    assert_equal expected, actual
  end

  def test_order_converts_to_sort_param
    expected = { sort: { 'Name' => 'desc' } }
    actual = @table.order('Name' => 'desc').to_h

    assert_equal expected, actual
  end

  def test_order_merges_multiple_calls
    expected = { sort: { 'Name' => 'desc', 'Rank' => 'asc' } }
    actual = @table
      .order('Name' => 'asc')
      .order('Name' => 'desc')
      .order('Rank' => 'asc')
      .to_h

    assert_equal expected, actual
  end

  def test_limit_produces_max_records_param
    assert_equal({ max_records: 1 }, @table.limit(1).to_h)
  end

  def test_limit_overwrites_multiple_calls
    expected = { max_records: 10 }
    actual = @table.limit(1).limit(3).limit(10).to_h

    assert_equal expected, actual
  end

  def test_chaining_multiple_methods_produces_valid_params
    expected = {
      filter: "AND({Name} = 'McCoy', {Rank} = 'Commander')",
      sort: { 'Name' => 'Asc' },
      max_records: 10,
    }

    actual = @table
      .where('Name' => 'McCoy', 'Rank' => 'Commander')
      .order('Name' => 'Asc')
      .limit(10)
      .to_h

    assert_equal expected, actual
  end
end
