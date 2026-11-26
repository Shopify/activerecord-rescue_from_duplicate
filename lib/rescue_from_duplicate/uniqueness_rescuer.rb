module RescueFromDuplicate
  class UniquenessRescuer
    def initialize(validator)
      @validator = validator
    end

    def rescue?
      @validator.options.fetch(:rescue_from_duplicate, false)
    end

    def options
      @validator.options
    end

    def index_name
      rescue_options = options[:rescue_from_duplicate]
      rescue_options[:index]&.to_s if rescue_options.is_a?(Hash)
    end

    def attributes
      @validator.attributes
    end

    def columns
      (Array(options[:scope]) + attributes).map(&:to_s).sort
    end
  end
end
