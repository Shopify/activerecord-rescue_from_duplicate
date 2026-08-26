require 'spec_helper'

module RescueFromDuplicate
  describe "#other_exception_columns (MySQL/MariaDB duplicate-key parsing)" do
    let(:prefix_index) do
      ::ActiveRecord::ConnectionAdapters::IndexDefinition.new(
        "order_transactions", "index_order_transactions_on_shop_id", false, ["shop_id"]
      )
    end
    let(:unique_index) do
      ::ActiveRecord::ConnectionAdapters::IndexDefinition.new(
        "order_transactions", "index_order_transactions_on_shop_id_and_unique_token", true, ["shop_id", "unique_token"]
      )
    end

    let(:model) do
      indexes = [prefix_index, unique_index]
      connection = double(schema_cache: double(indexes: indexes))
      Class.new do
        include RescueFromDuplicate::ActiveRecord::Extension
        define_singleton_method(:table_name) { "order_transactions" }
        define_singleton_method(:connection) { connection }
      end
    end

    subject(:columns) { model.allocate.send(:other_exception_columns, exception) }

    context "with a MySQL 8.0+ table-qualified key name" do
      let(:exception) do
        ::ActiveRecord::RecordNotUnique.new(
          "Duplicate entry '1-abc' for key 'order_transactions.index_order_transactions_on_shop_id_and_unique_token'"
        )
      end

      it "selects the violated index regardless of ordering" do
        expect(columns).to eq ["shop_id", "unique_token"]
      end
    end

    context "with a MySQL 5.7 / MariaDB bare key name" do
      let(:exception) do
        ::ActiveRecord::RecordNotUnique.new(
          "Duplicate entry '1-abc' for key 'index_order_transactions_on_shop_id_and_unique_token'"
        )
      end

      it "selects the violated index by exact name" do
        expect(columns).to eq ["shop_id", "unique_token"]
      end
    end

    context "when the message carries no key name" do
      let(:exception) { ::ActiveRecord::RecordNotUnique.new("some unrelated error") }

      it "returns no columns" do
        expect(columns).to eq []
      end
    end
  end
end
