module RescueFromDuplicate
  class Rescuer
    attr_reader :attributes, :options, :columns

    def initialize(attribute, options)
      @attributes = [attribute]
      @columns = [attribute, *Array(options[:scope])].map(&:to_s).sort
      @options = options
    end

    def rescue?
      true
    end

    def index_name
      options[:index]&.to_s
    end
  end
end
