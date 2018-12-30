module Airrecord
  # Airrecord::Table delegates to a new Airrecord::Relation when you use
  # ActiveRecord-style query methods like #where, #order, and #limit
  class Relation
    include Enumerable
    attr_reader :rules

    DEFAULT_RULES = { where: {}, order: {} }.freeze

    def initialize(table, rules = {})
      @table = table
      @rules = DEFAULT_RULES.merge(rules)
    end

    def where(conditions = {})
      new(where: rules[:where].merge(conditions))
    end

    def limit(count)
      new(limit: count.to_i)
    end

    def order(params)
      new(order: rules[:order].merge(params))
    end

    def each(&block)
      @table.records(record_params).each(&block)
    end

    private

    # Merge new_rules with @rules in a new relation
    def new(new_rules)
      self.class.new(@table, rules.merge(new_rules))
    end

    # Convert rules to a hash that Table#records can parse, omitting falsy keys
    def record_params
      wheres, orders, max = rules.values_at(:where, :order, :limit)
      filters = wheres.map { |key, val| "{#{key}} = '#{val}'" }
      [
        [:filter, filters.any? ? "AND(#{filters.join(', ')})" : nil],
        [:sort, orders.any? ? orders : nil],
        [:max_records, max]
      ].select { |_, val| val }.to_h
    end
  end
end
