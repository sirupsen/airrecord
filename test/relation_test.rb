require 'test_helper'

class RelationTest < MiniTest::Test
  def setup
    Airrecord::Relation.define_method(:inspect) do
      self.class.const_get(:RulesToRecordArgs).call rules
    end
    @relation = Airrecord::Relation.new('mock table')
  end

  def test_blank_relation_produces_empty_params
    assert_equal({}, @relation.where.inspect)
  end

  def test_where_with_one_key_makes_valid_filter
    expected = { filter: "AND({Rank} = 'Captain')" }
    actual = @relation.where("Rank" => "Captain").inspect

    assert_equal expected, actual
  end

  def test_where_with_many_keys_makes_valid_filter
    expected = { filter: "AND({Rank} = 'Captain', {Name} = 'Spock')" }
    actual = @relation.where("Rank" => "Captain", "Name" => "Spock").inspect

    assert_equal expected, actual
  end

  def test_where_merges_multiple_calls_into_valid_filter
    expected = { filter: "AND({Rank} = 'Captain', {Name} = 'Spock')" }
    actual = @relation
      .where("Rank" => "Captain")
      .where("Name" => "Spock")
      .inspect

    assert_equal expected, actual
  end

  def test_order_converts_to_sort_param
    expected = { sort: { 'Name' => 'Desc' } }
    actual = @relation.order('Name' => 'Desc').inspect

    assert_equal expected, actual
  end

  def test_order_merges_multiple_calls
    expected = { sort: { 'Name' => 'Desc', 'Rank' => 'Asc' } }
    actual = @relation
      .order('Name' => 'Asc')
      .order('Name' => 'Desc')
      .order('Rank' => 'Asc')
      .inspect

    assert_equal expected, actual
  end

  def test_limit_produces_max_records_param
    assert_equal({ max_records: 1 }, @relation.limit(1).inspect)
  end

  def test_limit_overwrites_multiple_calls
    expected = { max_records: 10 }
    actual = @relation.limit(1).limit(3).limit(10).inspect

    assert_equal expected, actual
  end

  def test_chaining_multiple_methods_produces_valid_params
    expected = {
      filter: "AND({Name} = 'McCoy', {Rank} = 'Commander')",
      sort: { 'Name' => 'Asc' },
      max_records: 10,
    }

    actual = @relation
      .where('Name' => 'McCoy', 'Rank' => 'Commander')
      .order('Name' => 'Asc')
      .limit(10)
      .inspect

    assert_equal expected, actual
  end
end
