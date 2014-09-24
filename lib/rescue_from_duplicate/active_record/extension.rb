require 'active_support/core_ext/class'

module RescueFromDuplicate::ActiveRecord
  module Extension
    extend ActiveSupport::Concern

    module ClassMethods
      def rescue_from_duplicate(attribute, options = {})
        self._rescue_from_duplicates += [RescueFromDuplicate::Rescuer.new(attribute, options)]
      end
    end

    included do
      class_attribute :_rescue_from_duplicates
      self._rescue_from_duplicates = []
    end

    def create_or_update(*params, &block)
      super
    rescue ActiveRecord::RecordNotUnique => exception
      handler = exception_validator(exception) || exception_rescuer(exception)

      raise exception unless handler

      attribute = handler.attributes.first
      options = handler.options.except(:case_sensitive, :scope).merge(value: self.send(:read_attribute_for_validation, attribute))

      self.errors.add(attribute, :taken, options)
      false
    end

    def exception_validator(exception)
      columns = exception_columns(exception)

      self._validators.each do |attribute, validators|
        validators.each do |validator|
          next unless validator.is_a?(ActiveRecord::Validations::UniquenessValidator)
          return validator if rescue_with_validator?(columns, validator)
        end
      end

      nil
    end

    protected

    def exception_columns(exception)
      columns = exception.message =~ /SQLite3::ConstraintException/ ? sqlite3_exception_columns(exception) : other_exception_columns(exception)
      columns.sort
    end

    def exception_rescuer(exception)
      columns = exception_columns(exception)

      _rescue_from_duplicates.detect { |rescuer| rescuer.matches?(columns) }
    end

    def sqlite3_exception_columns(exception)
      columns = exception.message[/column (.*) is not unique/, 1]
      return unless columns
      columns.split(",").map(&:strip)
    end

    def other_exception_columns(exception)
      indexes = self.class.connection.indexes(self.class.table_name)
      indexes.detect{ |i| exception.message.include?(i.name) }.try(:columns) || []
    end

    def rescue_with_validator?(columns, validator)
      validator_columns = (Array(validator.options[:scope]) + validator.attributes).map(&:to_s).sort
      return false unless columns == validator_columns
      validator.options.fetch(:rescue_from_duplicate) { false }
    end
  end
end
