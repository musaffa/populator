module Populator
  class Factory
    @factories = {}
    @depth = 0
    
    def self.for_model(model_class)
      @factories[model_class] ||= new(model_class)
    end
    
    def self.save_remaining_records
      @factories.values.each do |factory|
        factory.save_records
      end
      @factories = {}
    end
    
    def self.remember_depth
      @depth += 1
      yield
      @depth -= 1
      save_remaining_records if @depth.zero?
    end
    
    def initialize(model_class)
      @model_class = model_class
      @records = []
    end
    
    def populate(amount, &block)
      self.class.remember_depth do
        build_records(Populator.interpret_value(amount), &block)
      end
    end
    
    def build_records(amount, &block)
      amount.times do
        record = Record.new(@model_class, last_id_in_database + @records.size + 1)
        @records << record
        block.call(record) if block
      end
    end
    
    def save_records
      unless @records.empty?
        @model_class.connection.populate(@model_class.quoted_table_name, columns_sql, rows_sql_arr, "#{@model_class.name} Populate")
        @records.clear
      end
    end
    
    private
    
    def quoted_column_names
      @model_class.column_names.map do |column_name|
        @model_class.connection.quote_column_name(column_name)
      end
    end
    
    def last_id_in_database
      @last_id_in_database ||= @model_class.connection.select_value("SELECT id FROM #{@model_class.quoted_table_name} ORDER BY id DESC", "#{@model_class.name} Last ID").to_i
    end
    
    def columns_sql
      "(#{quoted_column_names.join(', ')})"
    end
    
    def rows_sql_arr
      @records.map do |record|
        quoted_attributes = record.attribute_values.map { |v| @model_class.sanitize(v) }
        "(#{quoted_attributes.join(', ')})"
      end
    end
  end
end
