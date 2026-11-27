require 'active_support'
require 'active_support/core_ext/object/try'
require "rescue_from_duplicate/active_record/version"

module RescueFromDuplicate
  module ActiveRecord
  end

  def self.missing_unique_indexes
    klasses = ::ActiveRecord::Base.descendants.select do |klass|
      klass.validators.any? { |v| v.is_a?(::ActiveRecord::Validations::UniquenessValidator) || klass._rescue_from_duplicates.any? }
    end

    missing_unique_indexes = []

    klasses.each do |klass|
      klass._rescue_from_duplicate_handlers.each do |handler|
        next unless klass.connection.table_exists?(klass.table_name)
        unique_indexes = klass.connection.schema_cache.indexes(klass.table_name).select(&:unique)

        unless unique_index_for?(unique_indexes, handler) || primary_key_for?(klass, handler)
          missing_unique_indexes << MissingUniqueIndex.new(klass, handler.attributes, handler.columns)
        end
      end
    end
    missing_unique_indexes
  end

  def self.unique_index_for?(unique_indexes, handler)
    unique_indexes.any? do |index|
      next true if handler.index_names.include?(index.name)

      # An expression index (`lower(email)`) has a String for its columns and can only match by name.
      index.columns.is_a?(Array) && index.columns.map(&:to_s).sort == handler.columns
    end
  end
  private_class_method :unique_index_for?

  # Active Record leaves the primary key out of `indexes`, so a handler that names it is checked here.
  def self.primary_key_for?(klass, handler)
    return false if handler.index_names.empty?

    name = primary_key_name(klass.connection, klass.table_name)
    !name.nil? && handler.index_names.include?(name)
  end
  private_class_method :primary_key_for?

  def self.primary_key_name(connection, table_name)
    return if Array(connection.schema_cache.primary_keys(table_name)).empty?

    case connection.adapter_name
    when /mysql|trilogy/i
      "PRIMARY"
    when /postg/i
      connection.select_value(<<~SQL)
        SELECT conname FROM pg_constraint
        WHERE contype = 'p' AND conrelid = #{connection.quote(connection.quote_table_name(table_name))}::regclass
      SQL
    end
  end
  private_class_method :primary_key_name
end

require 'rescue_from_duplicate/active_record/extension'
require 'rescue_from_duplicate/uniqueness_rescuer'
require 'rescue_from_duplicate/rescuer'
require 'rescue_from_duplicate/missing_unique_index'

ActiveSupport.on_load(:active_record) do
  ::ActiveRecord::Base.send :include, RescueFromDuplicate::ActiveRecord::Extension
end
