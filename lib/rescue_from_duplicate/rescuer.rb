module RescueFromDuplicate
  class Rescuer
    attr_reader :attributes, :options

    def initialize(attribute, options)
      @attributes = [attribute]
      @columns = [attribute, *Array(options[:scope])].map(&:to_s).sort
      @options = options
    end

    def matches?(columns)
      @columns == columns.map(&:to_s).sort
    end
  end
end
