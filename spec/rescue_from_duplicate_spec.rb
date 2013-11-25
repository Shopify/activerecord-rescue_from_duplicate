require 'spec_helper'
include RescueFromDuplicate

shared_examples 'database error rescuing' do
  let(:uniqueness_exception) { ActiveRecord::RecordNotUnique.new(message, nil) }

  subject { Rescuable.new }

  before do
    Rescuable.stub(:connection => double(:indexes => [Rescuable.index]))
  end

  describe "#exception_columns" do
    context "index cannot be found" do
      let(:message) { super().gsub(/index_\w+/, "index_toto").gsub(/column .* is/, 'toto') }
      let(:exception) { ActiveRecord::RecordNotUnique.new(message, nil) }

      it "returns nil" do
        expect(subject.exception_columns(exception)).to be_nil
      end
    end

    context "index can be found" do
      it "returns the columns" do
        expect(subject.exception_columns(uniqueness_exception).sort).to eq ["shop_id", "type", "name"].sort
      end
    end
  end

  describe "#exception_validator" do
    context "validator can be found" do
      it "returns the validator" do
        expect(subject.exception_validator(uniqueness_exception)).to eq Rescuable.uniqueness_validator
      end
    end

    context "validator cannot be found" do
      before {
        Rescuable.stub(:_validators => {:name => [Rescuable.presence_validator]})
      }

      it "returns nil" do
        expect(subject.exception_validator(uniqueness_exception)).to be_nil
      end
    end

    context "validator doesn't specify :rescue_with_errors" do
      before {
        Rescuable.stub(:_validators => {:name => [Rescuable.uniqueness_validator_without_rescue]})
      }

      it "returns nil" do
        expect(subject.exception_validator(uniqueness_exception)).to be_nil
      end
    end
  end

  describe "#create_or_update when the validation fails" do
    before { Base.stub(:exception => uniqueness_exception) }

    context "when the validator is present" do
      it "adds an error to the model" do
        subject.create_or_update
        expect(subject.errors[:name]).to eq ["has already been taken"]
      end
    end

    context "when the validator is not present" do
      before { Rescuable.stub(:_validators => {:name => [Rescuable.presence_validator]}) }

      it "raises an exception" do
        expect{ subject.create_or_update }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
end

describe ActiveRecord::RescueFromDuplicate do
  if defined?(MysqlModel)
    context 'mysql' do
      let(:message) { "Duplicate entry '1-Rescuable-toto' for key index_rescuable_on_shop_id_and_type_and_name" }
      it_behaves_like 'database error rescuing'
    end
  end

  if defined?(PostgresqlModel)
    context 'pgsql' do
      let(:message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_postgresql_models_on_name\"\nDETAIL:  Key (name)=(toto) already exists.\n: INSERT INTO \"postgresql_models\" (\"name\") VALUES ($1) RETURNING \"id\"" }
      it_behaves_like 'database error rescuing'
    end
  end

  context 'sqlite3' do
    let(:message) { "SQLite3::ConstraintException: column shop_id, type, name is not unique: INSERT INTO \"sqlite3_models\" (\"shop_id\", \"type\", \"name\") VALUES (?, ?, ?)" }
    it_behaves_like 'database error rescuing'
  end
end



