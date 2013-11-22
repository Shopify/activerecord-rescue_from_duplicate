module ActiveRecord::RescueFromDuplicate
  module Extension
    def create_or_update(*params, &block)
      super
    rescue ActiveRecord::RecordNotUnique => e
      validator = exception_validator(e)

      raise e unless validator

      attribute = validator.attributes.first
      options = validator.options.except(:case_sensitive, :scope).merge(:value => self.send(:read_attribute_for_validation, attribute))

      self.errors.add(attribute, :taken, options)
      false
    end

    def exception_validator(exception)
      columns = exception_columns(exception).sort

      self._validators.each do |attribute, validators|
        validators.each do |validator|
          next unless validator.is_a?(ActiveRecord::Validations::UniquenessValidator)
          return validator if columns == (Array(validator.options[:scope]) + validator.attributes).map(&:to_s).sort
        end
      end

      nil
    end

    def exception_columns(exception)
      indexes = self.class.connection.indexes(self.class.table_name)
      indexes.detect{ |i| exception.message.include?(i.name) }.try(:columns)
    end
  end
end
