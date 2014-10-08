require 'spec_helper'

describe RescueFromDuplicate::Rescuer do
  subject { RescueFromDuplicate::Rescuer.new(:shop_id, scope: :name) }

  context "#matches?" do
    it 'is true when the columns are the same' do
      expect(subject.matches?(["shop_id", "name"])).to be true
      expect(subject.matches?(["name", "shop_id"])).to be true
    end

    it 'is false when the columns are not the same' do
      expect(subject.matches?(["shop_id", "toto"])).to be false
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

if defined?(MysqlModel)
  describe MysqlModel do
    it_behaves_like 'a model with rescued unique error without validator'
  end
end

if defined?(PostgresqlModel)
  describe PostgresqlModel do
    it_behaves_like 'a model with rescued unique error without validator'
  end
end
