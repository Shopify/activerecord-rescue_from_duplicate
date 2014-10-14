module RescueFromDuplicate
  class Rescuer
    attr_reader :attributes, :options, :columns

    def initialize(attribute, options)
      @attributes = [attribute]
      @columns = [attribute, *Array(options[:scope])].map(&:to_s).sort
      @options = options.update(rescue_from_duplicate: true)
    end
  end
end
