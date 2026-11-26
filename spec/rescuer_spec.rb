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

  it "has no index name by default" do
    expect(subject.index_name).to be_nil
  end

  it "returns the index name from the index option" do
    rescuer = RescueFromDuplicate::Rescuer.new(:name, scope: :shop_id, index: :index_rescuable_on_shop_id_and_name)
    expect(rescuer.index_name).to eq "index_rescuable_on_shop_id_and_name"
  end
end

shared_examples 'a model with rescued unique error without validator' do
  describe 'create!' do
    context 'when catching a race condition' do
      before {
        described_class.create!(relation_id: 1, handle: 'toto')
      }

      it 'adds an error on the model' do
        model = described_class.create(relation_id: 1, handle: 'toto')
        expect(model.errors[:handle]).to eq(["handle must be unique for this relation"])
      end
    end
  end
end

describe Sqlite3Model do
  it_behaves_like 'a model with rescued unique error without validator'
end

describe MysqlModel do
  it_behaves_like 'a model with rescued unique error without validator'
end

describe PostgresqlModel do
  it_behaves_like 'a model with rescued unique error without validator'
end

shared_examples 'a model with a rescuer naming its index' do
  before { described_class.create!(relation_id: 1, code: 'toto', region: 1) }

  it 'adds an error on the model when the named index is violated' do
    model = described_class.create(relation_id: 1, code: 'toto', region: 1)
    expect(model.errors[:code]).to eq(["code must be unique for this relation"])
  end

  it 'does not put the index option in the error details' do
    model = described_class.create(relation_id: 1, code: 'toto', region: 1)
    expect(model.errors.details[:code].first).not_to have_key(:index)
  end
end

describe MysqlModel do
  it_behaves_like 'a model with a rescuer naming its index'
end

describe PostgresqlModel do
  it_behaves_like 'a model with a rescuer naming its index'
end

describe PostgresqlModel do
  it 'adds an error on the model when a named expression index is violated' do
    PostgresqlModel.create!(email: 'Toto@example.com')
    model = PostgresqlModel.create(email: 'toto@example.com')
    expect(model.errors[:email]).to eq(["email is already taken"])
  end
end

describe Sqlite3Model do
  it 'raises when the index columns do not match, because SQLite does not report the index name' do
    Sqlite3Model.create!(relation_id: 1, code: 'toto', region: 1)
    expect { Sqlite3Model.create(relation_id: 1, code: 'toto', region: 1) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
