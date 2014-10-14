module RescueFromDuplicate
  class MissingIndex
    attr_reader :model, :attributes, :columns

    def initialize(model, attributes, columns)
      @model = model
      @attributes = attributes
      @columns = columns
    end
  end
end
