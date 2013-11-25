require 'spec_helper'

shared_examples 'a model with rescued unique' do
  describe 'create!' do
    context 'when catching a race condition' do

      before(:each) {
        ActiveRecord::Validations::UniquenessValidator.any_instance.stub(:validate_each => nil)
        described_class.create!(:name => 'toto', :size => 5)
      }

      it 'raises an ActiveRecord::RecordNotSaved error' do
        expect{ described_class.create!(:name => 'toto') }.to raise_error(ActiveRecord::RecordNotSaved)
      end

      it "doesn't save the record" do
        expect{
          begin
            described_class.create!(:name => 'toto')
          rescue ActiveRecord::RecordNotSaved
            # NOOP
          end
        }.not_to change(described_class, :count)
      end

      it "rollback the transaction" do
        expect {
          begin
            described_class.transaction do
              described_class.create(:name => 'not toto', :size => 55)
              described_class.create!(:name => 'toto')
            end
          rescue ActiveRecord::RecordNotSaved
            # NOOP
          end
        }.not_to change(described_class, :count)
      end
    end

    context "with no race condition" do
      it 'saves the model' do
        expect{ described_class.create!(:name => 'toto') }.to change(described_class, :count).by(1)
      end
    end
  end
end

describe Sqlite3Model do
  it_behaves_like 'a model with rescued unique'
end

if defined?(MysqlModel)
  describe MysqlModel do
    it_behaves_like 'a model with rescued unique'
  end
end

if defined?(PostgresqlModel)
  describe PostgresqlModel do
    it_behaves_like 'a model with rescued unique'
  end
end
