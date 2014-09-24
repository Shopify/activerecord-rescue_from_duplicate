require 'spec_helper'
include RescueFromDuplicate

shared_examples 'database error rescuing' do
  let(:uniqueness_exception) { ::ActiveRecord::RecordNotUnique.new(message, nil) }

  subject { Rescuable.new }

  before do
    allow(Rescuable).to receive(:connection).and_return(double(indexes: [Rescuable.index]))
  end

  describe "#exception_validator" do
    context "validator can be found" do
      it "returns the validator" do
        expect(subject.exception_validator(uniqueness_exception)).to eq Rescuable.uniqueness_validator
      end
    end

    context "validator cannot be found" do
      before {
        Rescuable.stub(_validators: {name: [Rescuable.presence_validator]})
      }

      it "returns nil" do
        expect(subject.exception_validator(uniqueness_exception)).to be_nil
      end
    end

    context "validator doesn't specify :rescue_from_duplicate" do
      before {
        Rescuable.stub(_validators: {name: [Rescuable.uniqueness_validator_without_rescue]})
      }

      it "returns nil" do
        expect(subject.exception_validator(uniqueness_exception)).to be_nil
      end
    end

    context "no validator" do
      before {
        Rescuable.stub(_validators: {})
      }

      it "returns nil" do
        expect(subject.exception_validator(uniqueness_exception)).to be_nil
      end
    end

    context "no index on the table" do
      before {
        Rescuable.stub(index: nil)
        Rescuable.stub(connection: double(indexes: []))
      }

      let(:message) { super().gsub(/column (.*?) is/, 'column toto is').gsub(/Key \((.*?)\)=/, 'Key (toto)=') }

      it "returns nil" do
        expect(subject.exception_validator(uniqueness_exception)).to be_nil
      end
    end

    context "columns part of the index of another table" do
      before {
        subject.stub(exception_columns: ['foo', 'baz'])
      }

      it "returns nil" do
        expect(subject.exception_validator(uniqueness_exception)).to be_nil
      end
    end
  end

  describe "#create_or_update when the validation fails" do
    before { Base.stub(exception: uniqueness_exception) }

    context "when the validator is present" do
      it "adds an error to the model" do
        subject.create_or_update
        expect(subject.errors[:name]).to eq ["has already been taken"]
      end
    end

    context "when the validator is not present" do
      before { Rescuable.stub(_validators: {name: [Rescuable.presence_validator]}) }

      it "raises an exception" do
        expect{ subject.create_or_update }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#create_or_update when using rescuer without validation" do
    before {
      Rescuable.stub(_validators: {})
      Rescuable.stub(_rescue_from_duplicates: [Rescuable.uniqueness_rescuer])
      Base.stub(exception: uniqueness_exception)
    }

    it "adds an error to the model" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["is not unique by type and shop id"]
    end
  end
end

describe RescueFromDuplicate::ActiveRecord do
  if defined?(MysqlModel)
    context 'mysql' do
      let(:message) { "Duplicate entry '1-Rescuable-toto' for key 'index_rescuable_on_shop_id_and_type_and_name'" }
      it_behaves_like 'database error rescuing'
    end
  end

  if defined?(PostgresqlModel)
    context 'pgsql' do
      let(:message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_rescuable_on_shop_id_and_type_and_name\"\nDETAIL:  Key (shop_id, type, name)=(1, Rescuable, toto) already exists.\n: INSERT INTO \"postgresql_models\" (\"shop_id\", \"type\", \"name\") VALUES ($1, $2, $3) RETURNING \"id\"" }
      it_behaves_like 'database error rescuing'
    end
  end

  context 'sqlite3' do
    let(:message) { "SQLite3::ConstraintException: column shop_id, type, name is not unique: INSERT INTO \"sqlite3_models\" (\"shop_id\", \"type\", \"name\") VALUES (?, ?, ?)" }
    it_behaves_like 'database error rescuing'
  end
end
