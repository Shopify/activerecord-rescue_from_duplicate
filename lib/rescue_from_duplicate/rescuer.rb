module RescueFromDuplicate
  class Rescuer
    attr_reader :attributes, :options, :columns, :error_attribute

    def initialize(attribute, options)
      @error_attribute = options.delete(:add_error_to) || attribute
      @attributes = [attribute]
      @columns = [attribute, *Array(options[:scope])].map(&:to_s).sort
      @options = options
    end

    def rescue?
      true
    end
  end
end
