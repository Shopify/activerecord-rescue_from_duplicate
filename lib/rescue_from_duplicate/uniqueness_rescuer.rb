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

    def attributes
      @validator.attributes
    end

    def columns
      (Array(options[:scope]) + attributes).map(&:to_s).sort
    end
  end
end
