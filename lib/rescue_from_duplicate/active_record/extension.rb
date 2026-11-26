require 'active_support/core_ext/class'

module RescueFromDuplicate::ActiveRecord
  module Extension
    DUPLICATE_KEY_REGEX = /for key ['"](?<key>[^'"]+)['"]/

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
      options = handler.options.except(:case_sensitive, :scope, :index_name).merge(value: self.send(:read_attribute_for_validation, attribute))

      self.errors.add(attribute, :taken, **options)
      true
    end

    def exception_handler(exception)
      handlers = self.class._rescue_from_duplicate_handlers
      return if handlers.empty?

      handler_for_index_name(handlers, exception) || handler_for_columns(handlers, exception)
    end

    def handler_for_index_name(handlers, exception)
      named_handlers = handlers.reject { |handler| handler.index_names.empty? }
      return if named_handlers.empty?

      index_name = exception_index_name(exception)
      return unless index_name

      named_handlers.detect do |handler|
        handler.rescue? && handler.index_names.include?(index_name)
      end
    end

    def handler_for_columns(handlers, exception)
      columns = exception_columns(exception)
      return unless columns
      columns = columns.sort

      handlers.detect do |handler|
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

    def exception_index_name(exception)
      if exception.message =~ /SQLite3::ConstraintException/
        nil # SQLite reports the columns, never the index name.
      elsif exception.message =~ /PG::UniqueViolation/
        postgresql_exception_index_name(exception)
      else
        other_exception_index_name(exception)
      end
    end

    def postgresql_exception_index_name(exception)
      result = exception.cause.result if exception.cause.respond_to?(:result)
      index_name = result.error_field(PG::Constants::PG_DIAG_CONSTRAINT_NAME) if result && defined?(PG::Constants::PG_DIAG_CONSTRAINT_NAME)
      index_name || exception.message[/unique constraint "([^"]+)"/, 1]
    end

    def other_exception_index_name(exception)
      key = exception.message[DUPLICATE_KEY_REGEX, :key]
      return unless key

      # Mysql > 8.0 prefixes indexes with the table name.
      key.delete_prefix("#{self.class.table_name}.")
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
      index_name = other_exception_index_name(exception)
      return [] unless index_name

      indexes = self.class.connection.schema_cache.indexes(self.class.table_name)
      index = indexes.find { |i| i.name == index_name }
      index ? index.columns : []
    end
  end
end
