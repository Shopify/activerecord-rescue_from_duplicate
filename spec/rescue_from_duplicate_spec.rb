require 'spec_helper'
include RescueFromDuplicate

shared_examples 'database error rescuing' do
  let(:uniqueness_exception) { ::ActiveRecord::RecordNotUnique.new(message) }

  subject { Rescuable.new }

  describe "#create_or_update when the validation fails" do
    before { allow(Base).to(receive(:exception).and_return(uniqueness_exception)) }

    context "when the validator is present" do
      it "adds an error to the model" do
        subject.create_or_update
        expect(subject.errors[field]).to eq ["has already been taken"]
      end
    end

    context "when the validator is not present" do
      before { allow(Rescuable).to(receive(:validators).and_return([Rescuable.presence_validator])) }

      it "raises an exception" do
        expect { subject.create_or_update }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#create_or_update when using rescuer without validation" do
    before {
      allow(Rescuable).to(receive(:_validators).and_return({}))
      allow(Rescuable).to(receive(:_rescue_from_duplicates).and_return([rescuer]))
      allow(Base).to(receive(:exception).and_return(uniqueness_exception))
    }

    it "adds an error to the model" do
      subject.create_or_update
      expect(subject.errors[field]).to eq [without_validation_error]
    end
  end
end

describe RescueFromDuplicate::ActiveRecord do
  context 'unique key' do
    let(:field) { :name }
    let(:without_validation_error) { "is not unique by type and shop id" }
    let(:rescuer) { Rescuable.uniqueness_rescuer }

    before do
      allow(Rescuable).to(receive(:connection).and_return(double(
        indexes: [Rescuable.index],
        primary_keys: ["id"]
      )))
    end

    context 'mysql' do
      let(:message) { "Duplicate entry '1-Rescuable-toto' for key 'index_rescuable_on_shop_id_and_type_and_name'" }
      it_behaves_like 'database error rescuing'
    end

    context 'pgsql' do
      let(:message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_rescuable_on_shop_id_and_type_and_name\"\nDETAIL:  Key (shop_id, type, name)=(1, Rescuable, toto) already exists.\n: INSERT INTO \"postgresql_models\" (\"shop_id\", \"type\", \"name\") VALUES ($1, $2, $3) RETURNING \"id\"" }
      it_behaves_like 'database error rescuing'
    end

    context 'sqlite3' do
      let(:message) { "SQLite3::ConstraintException: column shop_id, type, name is not unique: INSERT INTO \"sqlite3_models\" (\"shop_id\", \"type\", \"name\") VALUES (?, ?, ?)" }
      it_behaves_like 'database error rescuing'
    end
  end

  context 'composite primary key' do
    let(:field) { :key }
    let(:without_validation_error) { "key must be unique within namespace" }
    let(:rescuer) { Rescuable.cpk_uniqueness_rescuer }

    before do
      allow(Rescuable).to(receive(:connection).and_return(double(
        indexes: [],
        primary_keys: ["namespace", "key"]
      )))
    end

    context 'mysql' do
      let(:message) { "Mysql2::Error: Duplicate entry 'existing_namespace-existing_key' for key 'PRIMARY'" }
      it_behaves_like 'database error rescuing'
    end

    context 'psql' do
      let(:message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"postgresql_cpk_models_pkey\"\nDETAIL:  Key (namespace, key)=(existing_namespace, existing_key) already exists.\n" }
      it_behaves_like 'database error rescuing'
    end

    context 'sqlite3' do
      let(:message) { "SQLite3::ConstraintException: UNIQUE constraint failed: sqlite3_cpk_models.namespace, sqlite3_cpk_models.key" }
      it_behaves_like 'database error rescuing'
    end
  end
end
