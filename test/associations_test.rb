require 'test_helper'

class Tea < Airrecord::Table
  self.api_key = "key1"
  self.base_key = "app1"
  self.table_name = "Teas"

  has_many :brews, class: "Brew", column: "Brews"
end

class Brew < Airrecord::Table
  self.api_key = "key1"
  self.base_key = "app1"
  self.table_name = "Brews"

  belongs_to :tea, class: "Tea", column: "Tea"
end

class AssociationsTest < MiniTest::Test
  def setup
    @stubs = Faraday::Adapter::Test::Stubs.new
    Airrecord::Table.client.connection = Faraday.new { |builder|
      builder.adapter :test, @stubs
    }
  end

  def test_has_many_associations
    tea = Tea.new(Name: "Dong Ding", Brews: ["rec2"])

    record = Brew.new(Name: "Good brew")
    stub_find_request(record, id: "rec2", table: Brew)

    assert_equal 1, tea[:brews].size
    assert_kind_of Airrecord::Table, tea[:brews].first
    assert_equal "rec2", tea[:brews].first.id
  end

  def test_belongs_to
    brew = Brew.new(Name: "Good Brew", Tea: ["rec1"])
    tea = Tea.new(Name: "Dong Ding", Brews: ["rec2"])
    stub_find_request(tea, table: Tea, id: "rec1")

    assert_equal "rec1", brew[:tea].id
  end

  def test_build_association_and_post_id
    tea = Tea.new({Name: "Jingning", Brews: []}, id: "rec1")
    brew = Brew.new(Name: "greeaat", Tea: [tea])
    stub_post_request(brew, table: Brew)

    brew.create

    stub_find_request(tea, table: Tea, id: "rec1")
    assert_equal tea.id, brew[:tea].id
  end

  def test_build_association_from_strings
    tea = Tea.new({Name: "Jingning", Brews: ["rec2"]})
    stub_post_request(tea, table: Tea)

    tea.create
  end
end
