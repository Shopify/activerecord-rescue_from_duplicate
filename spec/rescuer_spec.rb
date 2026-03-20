require 'spec_helper'

describe RescueFromDuplicate::Rescuer do
  subject { RescueFromDuplicate::Rescuer.new(:name, scope: [:type, :shop_id], message: "Derp!") }

  it "always rescues" do
    expect(subject.rescue?).to eq true
  end

  it "sorts the columns" do
    expect(subject.columns).to eq ['name', 'shop_id', 'type']
  end

  it "returns the options" do
    expect(subject.options).to eq scope: [:type, :shop_id], message: "Derp!"
  end

  describe "#error_attribute" do
    it "defaults to the declared attribute" do
      rescuer = RescueFromDuplicate::Rescuer.new(:name_normalized, scope: [:shop_id])
      expect(rescuer.error_attribute).to eq(:name_normalized)
    end

    it "returns the add_error_to attribute when provided" do
      rescuer = RescueFromDuplicate::Rescuer.new(:name_normalized, scope: [:shop_id], add_error_to: :name)
      expect(rescuer.error_attribute).to eq(:name)
    end

    it "strips add_error_to from options" do
      rescuer = RescueFromDuplicate::Rescuer.new(:name_normalized, scope: [:shop_id], add_error_to: :name, message: "taken")
      expect(rescuer.options).to eq(scope: [:shop_id], message: "taken")
    end
  end
end

shared_examples 'a model with rescued unique error without validator' do
  describe 'create!' do
    context 'when catching a race condition' do
      before {
        described_class.create!(relation_id: 1, handle: 'toto')
      }

      it 'adds an error on the model' do
        model = described_class.create(relation_id: 1, handle: 'toto')
        expect(model.errors[:handle]).to eq(["handle must be unique for this relation"])
      end
    end
  end
end

describe Sqlite3Model do
  it_behaves_like 'a model with rescued unique error without validator'
end

describe MysqlModel do
  it_behaves_like 'a model with rescued unique error without validator'
end

describe PostgresqlModel do
  it_behaves_like 'a model with rescued unique error without validator'
end
