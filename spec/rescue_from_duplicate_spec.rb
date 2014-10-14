require 'spec_helper'
include RescueFromDuplicate

shared_examples 'database error rescuing' do
  let(:uniqueness_exception) { ::ActiveRecord::RecordNotUnique.new(message, nil) }

  subject { Rescuable.new }

  before do
    allow(Rescuable).to receive(:connection).and_return(double(indexes: [Rescuable.index]))
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
      before { Rescuable.stub(validators: [Rescuable.presence_validator]) }

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
