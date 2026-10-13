require 'spec_helper'

module RescueFromDuplicate
  describe 'PostgreSQL duplicate errors without DETAIL' do
    let(:constraint_name) { Rescuable.index.name }
    let(:exception) do
      ::ActiveRecord::RecordNotUnique.new(
        "PG::UniqueViolation: ERROR: duplicate key value violates unique constraint \"#{constraint_name}\""
      )
    end
    let(:indexes) { [Rescuable.index] }
    let(:schema_cache) { double(indexes: indexes) }
    let(:connection) { double(schema_cache: schema_cache) }

    subject(:record) { Rescuable.new }

    before do
      allow(Rescuable).to receive(:connection).and_return(connection)
      allow(Base).to receive(:exception).and_return(exception)
    end

    it 'returns false and adds a taken error for an exact unique-index match' do
      expect(record.create_or_update).to eq false
      expect(record.errors[:name]).to eq ['has already been taken']
    end

    context 'with an explicit rescuer instead of a uniqueness validator' do
      before do
        allow(Rescuable).to receive(:validators).and_return([Rescuable.presence_validator])
        allow(Rescuable).to receive(:_rescue_from_duplicates).and_return([Rescuable.uniqueness_rescuer])
      end

      it 'adds the configured error' do
        expect(record.create_or_update).to eq false
        expect(record.errors[:name]).to eq ['is not unique by type and shop id']
      end
    end

    context 'when a shorter index name precedes the violated index' do
      let(:indexes) do
        [
          ::ActiveRecord::ConnectionAdapters::IndexDefinition.new('rescuable', 'index_rescuable_on_shop_id', true, ['shop_id']),
          Rescuable.index
        ]
      end

      it 'selects only the exact index name' do
        expect(record.create_or_update).to eq false
        expect(record.errors[:name]).to eq ['has already been taken']
      end
    end

    context 'when DETAIL is present' do
      let(:exception) do
        ::ActiveRecord::RecordNotUnique.new(
          'PG::UniqueViolation: ERROR: duplicate key value violates unique constraint "unknown_index"' \
          "\nDETAIL: Key (shop_id, type, name)=(1, Rescuable, example) already exists."
        )
      end

      it 'keeps using the reported columns without looking up indexes' do
        expect(connection).not_to receive(:schema_cache)
        expect(record.create_or_update).to eq false
        expect(record.errors[:name]).to eq ['has already been taken']
      end
    end

    shared_examples 'an unclassified duplicate' do
      it 're-raises the same exception without adding errors' do
        expect { record.create_or_update }.to raise_error(::ActiveRecord::RecordNotUnique) { |raised| expect(raised).to equal(exception) }
        expect(record.errors).to be_empty
      end
    end

    context 'when the constraint name is unknown' do
      let(:constraint_name) { 'unknown_index' }
      it_behaves_like 'an unclassified duplicate'
    end

    context 'when a physical index name differs from the schema index name' do
      let(:constraint_name) { "#{Rescuable.index.name}_partition_1" }
      it_behaves_like 'an unclassified duplicate'
    end

    context 'when no quoted constraint is reported' do
      let(:exception) { ::ActiveRecord::RecordNotUnique.new('PG::UniqueViolation: duplicate key value') }

      it 'does not look up indexes' do
        expect(connection).not_to receive(:schema_cache)
        expect { record.create_or_update }.to raise_error(::ActiveRecord::RecordNotUnique) { |raised| expect(raised).to equal(exception) }
      end
    end

    context 'when the index is not unique' do
      let(:indexes) do
        [::ActiveRecord::ConnectionAdapters::IndexDefinition.new('rescuable', constraint_name, false, ['shop_id', 'type', 'name'])]
      end
      it_behaves_like 'an unclassified duplicate'
    end

    context 'when the unique index has expression columns' do
      let(:indexes) do
        [::ActiveRecord::ConnectionAdapters::IndexDefinition.new('rescuable', constraint_name, true, 'lower(name)')]
      end
      it_behaves_like 'an unclassified duplicate'
    end

    context 'when the unique index has no columns' do
      let(:indexes) do
        [::ActiveRecord::ConnectionAdapters::IndexDefinition.new('rescuable', constraint_name, true, [])]
      end
      it_behaves_like 'an unclassified duplicate'
    end

    context 'when the index columns do not match a handler' do
      let(:indexes) do
        [::ActiveRecord::ConnectionAdapters::IndexDefinition.new('rescuable', constraint_name, true, ['name'])]
      end
      it_behaves_like 'an unclassified duplicate'
    end

    context 'when a quoted identifier contains an embedded quote' do
      let(:constraint_name) { "#{Rescuable.index.name}\"suffix" }
      it_behaves_like 'an unclassified duplicate'
    end

    context 'when only the SQL statement contains a constraint-like string' do
      let(:exception) do
        ::ActiveRecord::RecordNotUnique.new(
          "PG::UniqueViolation: duplicate key value\n: INSERT INTO examples (name) VALUES ('unique constraint \"#{constraint_name}\"')"
        )
      end
      it_behaves_like 'an unclassified duplicate'
    end

    context 'when querying metadata fails in an aborted transaction' do
      before do
        allow(schema_cache).to receive(:indexes).and_raise(::ActiveRecord::StatementInvalid, 'current transaction is aborted')
      end
      it_behaves_like 'an unclassified duplicate'
    end

    context 'when the metadata connection is unavailable' do
      before do
        allow(Rescuable).to receive(:connection).and_raise(::ActiveRecord::ConnectionNotEstablished)
      end
      it_behaves_like 'an unclassified duplicate'
    end
  end

  describe 'PostgreSQL duplicate classification with real schema metadata' do
    let(:connection) { PostgresqlModel.connection }
    let(:table_name) { PostgresqlModel.table_name }
    let(:exception) do
      ::ActiveRecord::RecordNotUnique.new(
        'PG::UniqueViolation: ERROR: duplicate key value violates unique constraint "index_postgresql_models_on_name"'
      )
    end

    subject(:record) { Rescuable.new }

    before do
      allow(Rescuable).to receive(:connection).and_return(connection)
      allow(Rescuable).to receive(:table_name).and_return(table_name)
      allow(Rescuable).to receive(:validators).and_return([Rescuable.presence_validator])
      allow(Rescuable).to receive(:_rescue_from_duplicates).and_return([RescueFromDuplicate::Rescuer.new(:name, {})])
      allow(Base).to receive(:exception).and_return(exception)
      connection.schema_cache.clear_data_source_cache!(table_name)
    end

    after do
      connection.schema_cache.clear_data_source_cache!(table_name)
    end

    it 'classifies a duplicate with cold metadata when the connection can query' do
      expect(record.create_or_update).to eq false
      expect(record.errors[:name]).to eq ['has already been taken']
    end

    it 'classifies a duplicate with warm metadata even when the transaction is aborted' do
      PostgresqlModel.create!(name: 'duplicate')
      connection.schema_cache.indexes(table_name)

      connection.transaction do
        expect { connection.execute("INSERT INTO postgresql_models (name) VALUES ('duplicate')") }.to raise_error(::ActiveRecord::RecordNotUnique)
        expect(record.create_or_update).to eq false
        expect(record.errors[:name]).to eq ['has already been taken']
        expect { connection.execute('SELECT 1') }.to raise_error(::ActiveRecord::StatementInvalid, /current transaction is aborted/)
      end
    end

    it 'preserves the original duplicate with cold metadata in an aborted transaction' do
      PostgresqlModel.create!(name: 'duplicate')

      connection.transaction do
        expect { connection.execute("INSERT INTO postgresql_models (name) VALUES ('duplicate')") }.to raise_error(::ActiveRecord::RecordNotUnique)
        expect { record.create_or_update }.to raise_error(::ActiveRecord::RecordNotUnique) { |raised| expect(raised).to equal(exception) }
        expect(record.errors).to be_empty
      end
    end
  end
end
