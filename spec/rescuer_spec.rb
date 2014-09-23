require 'spec_helper'

describe RescueFromDuplicate::Rescuer do
  subject { RescueFromDuplicate::Rescuer.new(:name, scope: :shop_id) }

  context "#matches?" do
    it 'is true when the columns are the same' do
      expect(subject.matches?(["shop_id", "name"])).to be true
    end

    it 'is false when the columns are not the same' do
      expect(subject.matches?(["shop_id", "toto"])).to be false
    end
  end
end
