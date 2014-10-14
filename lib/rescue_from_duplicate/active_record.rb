require 'active_support'
require 'active_support/core_ext/object/try'
require "rescue_from_duplicate/active_record/version"

module RescueFromDuplicate
  module ActiveRecord
  end

  def self.missing_indexes
    klasses = ::ActiveRecord::Base.subclasses.select do |klass|
      klass.validators.any? {|v| v.is_a?(::ActiveRecord::Validations::UniquenessValidator) || klass._rescue_from_duplicates.any? }
    end

    missing_indexes = []

    klasses.each do |klass|
      klass._rescue_from_duplicate_handlers.each do |handler|
        unique_indexes = klass.connection.indexes(klass.table_name).select(&:unique)

        unless unique_indexes.any? { |index| index.columns.map(&:to_s).sort == handler.columns }
          missing_indexes << MissingIndex.new(klass, handler.attributes, handler.columns)
        end
      end
    end
    missing_indexes
  end
end

require 'rescue_from_duplicate/active_record/extension'
require 'rescue_from_duplicate/uniqueness_rescuer'
require 'rescue_from_duplicate/rescuer'
require 'rescue_from_duplicate/missing_index'

ActiveSupport.on_load(:active_record) do
  ::ActiveRecord::Base.send :include, RescueFromDuplicate::ActiveRecord::Extension
end
