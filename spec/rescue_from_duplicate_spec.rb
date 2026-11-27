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
end

describe RescueFromDuplicate::ActiveRecord do
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

describe "RescueFromDuplicate::ActiveRecord matching by index name" do
  let(:named_rescuer) do
    RescueFromDuplicate::Rescuer.new(:name, scope: :shop_id, index_name: "index_rescuable_unique_name", message: "named")
  end
  let(:column_rescuer) do
    RescueFromDuplicate::Rescuer.new(:name, scope: [:shop_id, :type], message: "columns")
  end

  subject { Rescuable.new }

  before do
    connection = double(schema_cache: double(indexes: [Rescuable.index]))
    allow(Rescuable).to(receive(:connection).and_return(connection))
    allow(Rescuable).to(receive(:validators).and_return([]))
    allow(Rescuable).to(receive(:_rescue_from_duplicates).and_return([column_rescuer, named_rescuer]))
    allow(Base).to(receive(:exception).and_return(::ActiveRecord::RecordNotUnique.new(message)))
  end

  context "when a MySQL 8 error names the declared index, whose columns differ from the handler's" do
    let(:message) { "Duplicate entry '1-toto-0' for key 'rescuable.index_rescuable_unique_name'" }

    it "uses the handler that names the index" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["named"]
    end
  end

  context "when a MySQL 5.7 error names the declared index" do
    let(:message) { "Duplicate entry '1-toto-0' for key 'index_rescuable_unique_name'" }

    it "uses the handler that names the index" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["named"]
    end
  end

  context "when a PostgreSQL error names the declared index, whose columns differ from the handler's" do
    let(:message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_rescuable_unique_name\"\nDETAIL:  Key (shop_id, name, region)=(1, toto, 0) already exists." }

    it "uses the handler that names the index" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["named"]
    end
  end

  context "when a PostgreSQL-compatible error names the declared index without a DETAIL line" do
    let(:message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_rescuable_unique_name\"" }

    it "uses the handler that names the index" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["named"]
    end
  end

  context "when a SQLite error names the declared index" do
    let(:message) { "SQLite3::ConstraintException: UNIQUE constraint failed: index 'index_rescuable_unique_name'" }

    it "uses the handler that names the index" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["named"]
    end
  end

  context "when a SQLite error names an index that no handler names" do
    let(:message) { "SQLite3::ConstraintException: UNIQUE constraint failed: index 'index_rescuable_other'" }

    it "raises" do
      expect { subject.create_or_update }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  context "when the error names one of several indexes the handler names" do
    let(:named_rescuer) do
      RescueFromDuplicate::Rescuer.new(:name, scope: :shop_id, index_name: ["index_rescuable_other", "index_rescuable_unique_name"], message: "named")
    end
    let(:message) { "Duplicate entry '1-toto-0' for key 'rescuable.index_rescuable_unique_name'" }

    it "uses the handler that names the index" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["named"]
    end
  end

  context "when the error names another index" do
    let(:message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_rescuable_on_shop_id_and_type_and_name\"\nDETAIL:  Key (shop_id, type, name)=(1, Rescuable, toto) already exists." }

    it "falls back to matching the index columns" do
      subject.create_or_update
      expect(subject.errors[:name]).to eq ["columns"]
    end
  end

  context "when the error names another index and no handler matches its columns" do
    let(:message) { "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_rescuable_other\"\nDETAIL:  Key (shop_id, name, region)=(1, toto, 0) already exists." }

    it "raises" do
      expect { subject.create_or_update }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
