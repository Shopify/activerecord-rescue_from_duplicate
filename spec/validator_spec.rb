require 'spec_helper'

shared_examples 'a model with rescued uniqueness validator' do
  describe 'create!' do
    context 'when catching a race condition' do

      before(:each) {
        allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator)
          .to(receive(:validate_each)).and_return(nil)
        described_class.create!(name: 'toto', size: 5)
      }

      it 'raises an ActiveRecord::RecordNotSaved error' do
        expect{ described_class.create!(name: 'toto') }.to raise_error(ActiveRecord::RecordNotSaved)
      end

      it "doesn't save the record" do
        expect{
          begin
            described_class.create!(name: 'toto')
          rescue ActiveRecord::RecordNotSaved
            # NOOP
          end
        }.not_to change(described_class, :count)
      end

      it "rollback the transaction" do
        expect {
          begin
            described_class.transaction do
              described_class.create(name: 'not toto', size: 55)
              described_class.create!(name: 'toto')
            end
          rescue ActiveRecord::RecordNotSaved
            # NOOP
          end
        }.not_to change(described_class, :count)
      end
    end

    context "with no race condition" do
      it 'saves the model' do
        expect{ described_class.create!(name: 'toto') }.to change(described_class, :count).by(1)
      end
    end
  end
end

shared_examples 'a model with a uniqueness validation naming its index' do
  before do
    allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to(receive(:validate_each)).and_return(nil)
    described_class.create!(relation_id: 1, serial: 'toto', region: 1)
  end

  it 'adds a taken error when the named index, whose columns differ from the validation, is violated' do
    model = described_class.create(relation_id: 1, serial: 'toto', region: 1)
    expect(model).not_to be_persisted
    expect(model.errors[:serial]).to eq ["has already been taken"]
    expect(model.errors.details[:serial].first[:error]).to eq :taken
  end
end

shared_examples 'missing primary key finding' do |primary_key_name|
  it 'accepts a handler that names the primary key' do
    allow(described_class).to(receive(:_rescue_from_duplicate_handlers).and_return([
      RescueFromDuplicate::Rescuer.new(:id, index_name: ["index_that_does_not_exist", primary_key_name]),
    ]))

    missing_unique_indexes = RescueFromDuplicate.missing_unique_indexes.select { |mi| mi.model == described_class }
    expect(missing_unique_indexes).to be_empty
  end

  it 'reports a handler on the primary key column that names another index' do
    allow(described_class).to(receive(:_rescue_from_duplicate_handlers).and_return([
      RescueFromDuplicate::Rescuer.new(:id, index_name: "index_that_does_not_exist"),
    ]))

    missing_unique_indexes = RescueFromDuplicate.missing_unique_indexes.select { |mi| mi.model == described_class }
    expect(missing_unique_indexes.map(&:columns)).to eq [["id"]]
  end
end

shared_examples 'missing index finding' do
  describe do
    context 'all indexes are satisfied' do
      it 'returns an empty array' do
        expect(RescueFromDuplicate.missing_unique_indexes).to be_empty
      end
    end

    context 'indexes are missing' do
      before {
        allow(described_class).to(receive(:_rescue_from_duplicate_handlers).and_return([
          RescueFromDuplicate::UniquenessRescuer.new(
            ::ActiveRecord::Validations::UniquenessValidator.new(
              attributes: [:name],
              case_sensitive: true, scope: [:titi, :toto],
              class: described_class,
            )
          ),
          RescueFromDuplicate::Rescuer.new(:name, scope: [:hello])
        ]))
      }

      it 'reports a handler whose named index does not exist' do
        allow(described_class).to(receive(:_rescue_from_duplicate_handlers).and_return([
          RescueFromDuplicate::Rescuer.new(:code, scope: :relation_id, index_name: "index_that_does_not_exist"),
        ]))

        missing_unique_indexes = RescueFromDuplicate.missing_unique_indexes.select { |mi| mi.model == described_class }
        expect(missing_unique_indexes.map(&:columns)).to eq [["code", "relation_id"]]
      end

      it 'accepts a handler when one of its named indexes is a unique index' do
        allow(described_class).to(receive(:_rescue_from_duplicate_handlers).and_return([
          RescueFromDuplicate::Rescuer.new(:code, scope: :relation_id, index_name: ["index_that_does_not_exist", "index_#{described_class.table_name}_unique_code"]),
        ]))

        missing_unique_indexes = RescueFromDuplicate.missing_unique_indexes.select { |mi| mi.model == described_class }
        expect(missing_unique_indexes).to be_empty
      end

      it 'accepts a handler whose named index does not exist when a unique index has its columns' do
        allow(described_class).to(receive(:_rescue_from_duplicate_handlers).and_return([
          RescueFromDuplicate::Rescuer.new(:handle, scope: :relation_id, index_name: "index_that_does_not_exist"),
        ]))

        missing_unique_indexes = RescueFromDuplicate.missing_unique_indexes.select { |mi| mi.model == described_class }
        expect(missing_unique_indexes).to be_empty
      end

      it 'returns the missing indexes' do
        missing_unique_indexes = RescueFromDuplicate.missing_unique_indexes.select { |mi| mi.model == described_class }
        expect(missing_unique_indexes).not_to be_empty

        expect(missing_unique_indexes.first.model).to eq described_class
        expect(missing_unique_indexes.last.model).to eq described_class

        expect(missing_unique_indexes.first.attributes).to eq [:name]
        expect(missing_unique_indexes.last.attributes).to eq [:name]

        expect(missing_unique_indexes.first.columns).to eq ["name", "titi", "toto"]
        expect(missing_unique_indexes.last.columns).to eq ["hello", "name"]
      end
    end
  end
end

describe Sqlite3Model do
  it_behaves_like 'a model with rescued uniqueness validator'
  it_behaves_like 'missing index finding'
end

describe MysqlModel do
  it_behaves_like 'a model with rescued uniqueness validator'
  it_behaves_like 'a model with a uniqueness validation naming its index'
  it_behaves_like 'missing index finding'
  it_behaves_like 'missing primary key finding', "PRIMARY"
end

describe PostgresqlModel do
  it_behaves_like 'a model with rescued uniqueness validator'
  it_behaves_like 'a model with a uniqueness validation naming its index'
  it_behaves_like 'missing index finding'
  it_behaves_like 'missing primary key finding', "postgresql_models_pkey"
end
