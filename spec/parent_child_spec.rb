require 'spec_helper'

module RescueFromDuplicate
  class Company < ::ActiveRecord::Base
    has_many(:employees)
  end

  class Employee < ::ActiveRecord::Base
    validates_uniqueness_of :name, rescue_from_duplicate: true
    has_many(:clients)
  end

  class Client < ::ActiveRecord::Base
    validates_uniqueness_of :address, rescue_from_duplicate: true
  end
end

describe 'a model whose child has a rescued uniquenes validator' do
  describe 'save' do
    before(:all) {
      # Reset DB state
      Client.delete_all
      Employee.delete_all
      Company.delete_all

      # Set up models
      emp1 = Employee.new(:name => "Bob")
      emp2 = Employee.new(:name => "Bob")
      @comp = Company.new()
      @comp.employees << emp1 << emp2
      @result = @comp.save
    }

    it "returns false" do
      expect(@result).to eq false
    end

    it "does not save the company" do
      expect(Company.count).to eq 0
    end

    it "does not save the employees" do
      expect(Employee.count).to eq 0
    end

    it "has errors" do
      expect(@comp.errors).not_to be_empty
    end

    it "has a specific error" do
      expect(@comp.errors[:employees]).to eq "TODO"
    end

    it "has an error on the employee" do
      expect(@comp.employees[1].errors[:name]).to eq ["has already been taken"]
    end
  end
end

describe 'a model whose grandchild has a rescued uniquenes validator' do
  describe 'save' do
    before(:all) {
      # Reset DB state
      Client.delete_all
      Employee.delete_all
      Company.delete_all

      # Set up models
      c1 = Client.new(:address => "Mars")
      c2 = Client.new(:address => "Mars")
      emp = Employee.new()
      emp.clients << c1 << c2
      @comp = Company.new()
      @comp.employees << emp
      @result = @comp.save
    }

    it "returns false" do
      expect(@result).to eq false
    end

    it "does not save the company" do
      expect(Company.count).to eq 0
    end

    it "does not save the employees" do
      expect(Employee.count).to eq 0
    end

    it "has errors" do
      expect(@comp.errors).not_to be_empty
    end

    it "has a specific error" do
      expect(@comp.errors[:employees]).to eq "TODO"
    end

    it "has an error on the employee" do
      expect(@comp.employees[0].errors[:clients]).to eq "TODO"
    end

    it "has an error on the client" do
      expect(@comp.employees[0].clients[1].errors[:address]).to eq ["has already been taken"]
    end
  end
end