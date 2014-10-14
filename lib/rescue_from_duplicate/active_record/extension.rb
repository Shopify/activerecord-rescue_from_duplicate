require 'active_support/core_ext/class'

module RescueFromDuplicate::ActiveRecord
  module Extension
    extend ActiveSupport::Concern

    module ClassMethods
      def rescue_from_duplicate(attribute, options = {})
        self._rescue_from_duplicates += [RescueFromDuplicate::Rescuer.new(attribute, options)]
      end

      def rescue_from_duplicate_handlers
        self._rescue_from_duplicates + self.validators.select { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
      end
    end

    included do
      class_attribute :_rescue_from_duplicates
      self._rescue_from_duplicates = []
    end

    def create_or_update(*params, &block)
      super
    rescue ActiveRecord::RecordNotUnique => exception
      handler = exception_handler(exception)

      raise exception unless handler

      attribute = handler.attributes.first
      options = handler.options.except(:case_sensitive, :scope).merge(value: self.send(:read_attribute_for_validation, attribute))

      self.errors.add(attribute, :taken, options)
      false
    end

    def exception_handler(exception)
      columns = exception_columns(exception)

      self.class.rescue_from_duplicate_handlers.detect do |handler|
        validator_columns = (Array(handler.options[:scope]) + handler.attributes).map(&:to_s).sort
        columns == validator_columns && handler.options.fetch(:rescue_from_duplicate) { false }
      end
    end

    protected

    def exception_columns(exception)
      columns = case
      when exception.message =~ /SQLite3::ConstraintException/
        sqlite3_exception_columns(exception)
      when exception.message =~ /PG::UniqueViolation/
        postgresql_exception_columns(exception)
      else
        other_exception_columns(exception)
      end
    end

    def postgresql_exception_columns(exception)
      extract_columns(exception.message[/Key \((.*?)\)=\(.*?\) already exists./, 1])
    end

    def sqlite3_exception_columns(exception)
      extract_columns(exception.message[/columns? (.*) (?:is|are) not unique/, 1])
    end

    def extract_columns(columns_string)
      return unless columns_string
      columns_string.split(",").map(&:strip).sort
    end

    def other_exception_columns(exception)
      indexes = self.class.connection.indexes(self.class.table_name)
      columns = indexes.detect{ |i| exception.message.include?(i.name) }.try(:columns) || []
      columns.sort
    end
  end
end
