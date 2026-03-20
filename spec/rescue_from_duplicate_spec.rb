require 'spec_helper'
include RescueFromDuplicate

shared_examples 'database error rescuing' do
  let(:uniqueness_exception) { ::ActiveRecord::RecordNotUnique.new(message) }

  subject { Rescuable.new }

  before do
    connection = double(schema_cache: double(indexes: [Rescuable.index]))
    allow(Rescuable).to(receive(:connection).and_return(connection))
  end

  describe "#create_or_update when the validation fails" do
    before { allow(Base).to(receive(:exception).and_return(uniqueness_exception)) }

    context "when the validator is present" do
      it "adds an error to the model" do
        subject.create_or_update
        expect(subject.errors[:name]).to eq ["has already been taken"]
      end
    end

    context "when the validator is not present" do
      before { allow(Rescuable).to(receive(:validators).and_return([Rescuable.presence_validator])) }

      it "raises an exception" do
        expect { subject.create_or_update }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "doesn't parse the message" do
        allow(uniqueness_exception).to(
          receive(:message).and_raise(StandardError, "Message should not have been accessed")
        )
        expect { subject.create_or_update }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "#create_or_update when using rescuer without validation" do
    before {
      allow(Rescuable).to(receive(:_validators).and_return({}))
      allow(Rescuable).to(receive(:_rescue_from_duplicates).and_return([Rescuable.uniqueness_rescuer]))
      allow(Base).to(receive(:exception).and_return(uniqueness_exception))
    }

    it "adds an error to the model" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["is not unique by type and shop id"]
    end
  end

  describe "#create_or_update when using rescuer with add_error_to" do
    let(:add_error_to_exception) { ::ActiveRecord::RecordNotUnique.new(name_normalized_message) }

    before {
      connection = double(schema_cache: double(indexes: [Rescuable.index_on_name_normalized]))
      allow(Rescuable).to(receive(:connection).and_return(connection))
      allow(Rescuable).to(receive(:_validators).and_return({}))
      allow(Rescuable).to(receive(:_rescue_from_duplicates).and_return([Rescuable.uniqueness_rescuer_with_add_error_to]))
      allow(Base).to(receive(:exception).and_return(add_error_to_exception))
      subject.name = "My Title"
    }

    it "adds the error to the alternate attribute" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["is not unique"]
    end

    it "reads the value from the alternate attribute" do
      subject.create_or_update
      expect(subject.errors.where(:name, :taken).first.options[:value]).to eq("My Title")
    end

    it "does not add an error to the index-matching attribute" do
      subject.create_or_update
      expect(subject.errors[:name_normalized]).to be_empty
    end
  end
end

describe RescueFromDuplicate::ActiveRecord do
  context 'mysql' do
    let(:message) { "Duplicate entry '1-Rescuable-toto' for key 'index_rescuable_on_shop_id_and_type_and_name'" }
    let(:name_normalized_message) { "Duplicate entry '1-Rescuable-toto' for key 'index_rescuable_on_shop_id_and_type_and_name_normalized'" }
    it_behaves_like 'database error rescuing'
  end

  context 'pgsql' do
    let(:message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_rescuable_on_shop_id_and_type_and_name\"\nDETAIL:  Key (shop_id, type, name)=(1, Rescuable, toto) already exists.\n: INSERT INTO \"postgresql_models\" (\"shop_id\", \"type\", \"name\") VALUES ($1, $2, $3) RETURNING \"id\"" }
    let(:name_normalized_message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_rescuable_on_shop_id_and_type_and_name_normalized\"\nDETAIL:  Key (shop_id, type, name_normalized)=(1, Rescuable, toto) already exists.\n: INSERT INTO \"postgresql_models\" (\"shop_id\", \"type\", \"name_normalized\") VALUES ($1, $2, $3) RETURNING \"id\"" }
    it_behaves_like 'database error rescuing'
  end

  context 'sqlite3' do
    let(:message) { "SQLite3::ConstraintException: column shop_id, type, name is not unique: INSERT INTO \"sqlite3_models\" (\"shop_id\", \"type\", \"name\") VALUES (?, ?, ?)" }
    let(:name_normalized_message) { "SQLite3::ConstraintException: column shop_id, type, name_normalized is not unique: INSERT INTO \"sqlite3_models\" (\"shop_id\", \"type\", \"name_normalized\") VALUES (?, ?, ?)" }
    it_behaves_like 'database error rescuing'
  end
end
