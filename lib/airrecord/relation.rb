module Airrecord
  # Airrecord::Table delegates to a new Airrecord::Relation when you use
  # ActiveRecord-style query methods like #where, #order, and #limit
  class Relation
    include Enumerable
    attr_reader :conditions

    DEFAULT_CONDITIONS = { where: {}, order: {} }.freeze

    def initialize(table, conditions = {})
      @table = table
      @conditions = DEFAULT_CONDITIONS.merge(conditions)
    end

    def where(params = {})
      new(where: conditions[:where].merge(params))
    end

    def limit(count)
      new(limit: count.to_i)
    end

    def order(params)
      new(order: conditions[:order].merge(params))
    end

    def each(&block)
      @table.records(record_params).each(&block)
    end

    private

    # Merge more_conditions with @conditions in a new Relation
    def new(more_conditions)
      self.class.new(@table, conditions.merge(more_conditions))
    end

    # Convert conditions to a hash that Table#records can parse, omitting falsy keys
    def record_params
      wheres, orders, max = conditions.values_at(:where, :order, :limit)
      filters = wheres.map { |key, val| "{#{key}} = '#{val}'" }
      [
        [:filter, filters.any? ? "AND(#{filters.join(', ')})" : nil],
        [:sort, orders.any? ? orders : nil],
        [:max_records, max]
      ].select { |_, val| val }.to_h
    end
  end
end
