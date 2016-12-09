module RescueFromDuplicate
  class Rescuer
    attr_reader :attributes, :options, :columns

    def initialize(attribute, options)
      @attributes = attribute.is_a?(Array)? attribute : [attribute]
      @columns = (@attributes + [options[:scope]]).map(&:to_s).sort
      @options = options
    end

    def rescue?
      true
    end
  end
end
