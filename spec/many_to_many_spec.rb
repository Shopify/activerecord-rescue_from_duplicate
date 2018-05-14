require 'spec_helper'

module RescueFromDuplicate
  class Item < ::ActiveRecord::Base
    has_many :memberships
    has_many :subsets, through: :memberships
  end

  class Membership < ::ActiveRecord::Base
    belongs_to :item
    belongs_to :subset

    validates :item_id, uniqueness: { scope: [:subset_id], rescue_from_duplicate: true, message: "already exists" }
  end

  class Subset < ::ActiveRecord::Base
    has_many :memberships
    has_many :items, through: :memberships
  end
end

shared_examples 'a model in a many-to-many relationship with unique pairings' do
  describe 'save subset' do
    before(:all) {
      # Reset DB state
      Membership.delete_all
      Item.delete_all
      Subset.delete_all

      # Set up models
      item = Item.new()
      item.save
      @subset = Subset.new()
      @subset.items << item << item
      @result = @subset.save
    }

    it "returns false" do
      expect(@result).to eq false
    end

    it "does not save the subset" do
      expect(Subset.count).to eq 0
    end

    it "does not save the memberships" do
      expect(Membership.count).to eq 0
    end

    it "has errors" do
      expect(@subset.errors).not_to be_empty
    end

    it "has a specific error" do
      expect(@subset.errors[:items]).to eq "TODO"
    end

    it "has an error on the duplicate membership" do
      expect(@subset.memberships[1].errors[:item_id]).to eq ["already exists"]
    end
  end

  describe 'save item' do
    before(:all) {
      # Reset DB state
      Membership.delete_all
      Item.delete_all
      Subset.delete_all

      # Set up models
      subset = Subset.new()
      subset.save
      @item = Item.new()
      @item.subsets << subset << subset
      @result = @item.save
    }

    it "returns false" do
      expect(@result).to eq false
    end

    it "does not save the item" do
      expect(Item.count).to eq 0
    end

    it "does not save the memberships" do
      expect(Membership.count).to eq 0
    end

    it "has errors" do
      expect(@item.errors).not_to be_empty
    end

    it "has a specific error" do
      expect(@item.errors[:subsets]).to eq "TODO"
    end

    it "has an error on the duplicate membership" do
      expect(@item.memberships[1].errors[:item_id]).to eq ["already exists"]
    end
  end
end

describe 'mysql' do
  before {
    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_mysql))
  }

  it_behaves_like 'a model in a many-to-many relationship with unique pairings'
end

describe 'pgsql' do
  before {
    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_postgresql))
  }

  it_behaves_like 'a model in a many-to-many relationship with unique pairings'
end

describe 'sqlite3' do
  before {
    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_sqlite3))
  }

  it_behaves_like 'a model in a many-to-many relationship with unique pairings'
end