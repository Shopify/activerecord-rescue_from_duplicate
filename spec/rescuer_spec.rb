require 'spec_helper'

describe RescueFromDuplicate::Rescuer do
  subject { RescueFromDuplicate::Rescuer.new(:name, scope: [:type, :shop_id], message: "Derp!") }

  it "always rescues" do
    expect(subject.rescue?).to eq true
  end

  it "sorts the columns" do
    expect(subject.columns).to eq ['name', 'shop_id', 'type']
  end

  it "returns the options" do
    expect(subject.options).to eq scope: [:type, :shop_id], message: "Derp!"
  end
end

shared_examples 'a model with rescued unique error without validator' do
  describe 'create!' do
    context 'when catching a race condition' do
      before {
        described_class.create!(params)
      }

      it 'adds an error on the model' do
        model = described_class.create(params)
        expect(model.errors[field]).to eq([error_message])
      end
    end
  end
end

context "unique key" do
  let(:params) { { relation_id: 1, handle: 'toto' } }
  let(:field) { :handle }
  let(:error_message) { "handle must be unique for this relation" }

  describe Sqlite3Model do
    it_behaves_like 'a model with rescued unique error without validator'
  end

  describe MysqlModel do
    it_behaves_like 'a model with rescued unique error without validator'
  end

  describe PostgresqlModel do
    it_behaves_like 'a model with rescued unique error without validator'
  end
end

context "composite primary key" do
  let(:params) { { namespace: 'test_namespace', key: 'test_key' } }
  let(:field) { :key }
  let(:error_message) { "must be unique within this namespace" }

  describe Sqlite3CpkNoValidatorModel do
    it_behaves_like 'a model with rescued unique error without validator'
  end

  describe MysqlCpkNoValidatorModel do
    it_behaves_like 'a model with rescued unique error without validator'
  end

  describe PsqlCpkNoValidatorModel do
    it_behaves_like 'a model with rescued unique error without validator'
  end
end
