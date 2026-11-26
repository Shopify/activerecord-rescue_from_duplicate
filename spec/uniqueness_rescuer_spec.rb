require 'spec_helper'

describe RescueFromDuplicate::UniquenessRescuer do
  context "common" do
    subject { RescueFromDuplicate::UniquenessRescuer.new(Rescuable.uniqueness_validator) }

    it "returns the options" do
      options = { case_sensitive: true, scope: [:type, :shop_id], rescue_from_duplicate: true }
      expect(subject.options).to eq options
    end

    it "sorts the columns" do
      expect(subject.columns).to eq ['name', 'shop_id', 'type']
    end

    it "returns the attributes" do
      expect(subject.attributes).to eq [:name]
    end
  end

  context "validator with rescue" do
    subject { RescueFromDuplicate::UniquenessRescuer.new(Rescuable.uniqueness_validator) }
    it "rescues" do
      expect(subject.rescue?).to eq true
    end
  end

  context "validator with rescue naming indexes" do
    let(:validator) do
      ::ActiveRecord::Validations::UniquenessValidator.new(
        attributes: [:name],
        scope: [:shop_id],
        rescue_from_duplicate: { index_name: ["index_rescuable_on_shop_id_and_name", "rescuable_pkey"] },
      ).tap { |o| o.setup(Rescuable) if o.respond_to?(:setup) }
    end
    subject { RescueFromDuplicate::UniquenessRescuer.new(validator) }

    it "rescues" do
      expect(subject.rescue?).to be_truthy
    end

    it "returns the index names" do
      expect(subject.index_names).to eq ["index_rescuable_on_shop_id_and_name", "rescuable_pkey"]
    end
  end

  context "validator with rescue: true" do
    subject { RescueFromDuplicate::UniquenessRescuer.new(Rescuable.uniqueness_validator) }

    it "has no index names" do
      expect(subject.index_names).to eq []
    end
  end

  context "validator without rescue" do
    subject { RescueFromDuplicate::UniquenessRescuer.new(Rescuable.uniqueness_validator_without_rescue) }
    it "doesn't rescues" do
      expect(subject.rescue?).to eq false
    end
  end
end
