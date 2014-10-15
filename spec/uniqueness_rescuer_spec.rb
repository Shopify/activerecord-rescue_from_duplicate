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

  context "validator without rescue" do
    subject { RescueFromDuplicate::UniquenessRescuer.new(Rescuable.uniqueness_validator_without_rescue) }
    it "doesn't rescues" do
      expect(subject.rescue?).to eq false
    end
  end
end
