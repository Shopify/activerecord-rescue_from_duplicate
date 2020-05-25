require 'active_support/core_ext/class'

module RescueFromDuplicate::ActiveRecord
  module Extension
    extend ActiveSupport::Concern

    module ClassMethods
      def rescue_from_duplicate(attribute, options = {})
        self._rescue_from_duplicates += [RescueFromDuplicate::Rescuer.new(attribute, options)]
      end

      def _rescue_from_duplicate_handlers
        validator_handlers = self.validators.select { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }.map do |v|
          RescueFromDuplicate::UniquenessRescuer.new(v)
        end
        self._rescue_from_duplicates + validator_handlers
      end
    end

    included do
      class_attribute :_rescue_from_duplicates
      self._rescue_from_duplicates = []
    end

    def create_or_update(*, **)
      super
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => exception
      raise unless handle_unicity_error(exception)
      false
    end

    private

    def handle_unicity_error(exception)
      handler = exception_handler(exception)
      return false unless handler

      attribute = handler.attributes.first
      options = handler.options.except(:case_sensitive, :scope).merge(value: self.send(:read_attribute_for_validation, attribute))

      self.errors.add(attribute, :taken, **options)
      true
    end

    def exception_handler(exception)
      columns = exception_columns(exception)
      return unless columns
      columns = columns.sort

      self.class._rescue_from_duplicate_handlers.detect do |handler|
        handler.rescue? && columns == handler.columns
      end
    end

    def exception_columns(exception)
      if exception.message =~ /SQLite3::ConstraintException/
        sqlite3_exception_columns(exception)
      elsif exception.message =~ /PG::UniqueViolation/
        postgresql_exception_columns(exception)
      else
        other_exception_columns(exception)
      end
    end

    def postgresql_exception_columns(exception)
      extract_columns(exception.message[/Key \((.*?)\)=\(.*?\) already exists./, 1])
    end

    def sqlite3_exception_columns(exception)
      extract_columns(exception.message[/columns? (.*) (?:is|are) not unique/, 1]) || 
      extract_columns(exception.message[/UNIQUE constraint failed: ([^:]*)\:?/, 1])
    end

    def extract_columns(columns_string)
      return unless columns_string
      columns_string.split(",").map { |column| column.split('.').last.strip }
    end

    def other_exception_columns(exception)
      indexes = self.class.connection.indexes(self.class.table_name)
      indexes.detect{ |i| exception.message.include?(i.name) }.try(:columns) || []
    end
  end
end
