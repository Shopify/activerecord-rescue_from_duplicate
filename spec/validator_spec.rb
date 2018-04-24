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
            )
          ),
          RescueFromDuplicate::Rescuer.new(:name, scope: [:hello])
        ]))
      }

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

if defined?(MysqlModel)
  describe MysqlModel do
    it_behaves_like 'a model with rescued uniqueness validator'
    it_behaves_like 'missing index finding'
  end
end

if defined?(PostgresqlModel)
  describe PostgresqlModel do
    it_behaves_like 'a model with rescued uniqueness validator'
    it_behaves_like 'missing index finding'
  end
end
