require 'active_record'
require 'json'
require 'yaml'

AR_VERSION = Gem::Version.new(ActiveRecord::VERSION::STRING)
AR_4_0 = Gem::Version.new('4.0')
AR_4_1 = Gem::Version.new('4.1.0.beta')

ActiveRecord::Base.configurations = {
  'test_sqlite3' => {adapter: 'sqlite3', database: "/tmp/rescue_from_duplicate.db"},
  'test_postgresql' => {adapter: 'postgresql', database: 'rescue_from_duplicate', username: 'postgres'},
  'test_mysql' => {adapter: 'mysql2', database: 'rescue_from_duplicate', username: 'travis'},
}

class CreateAllTables < ActiveRecord::Migration
  def self.recreate_table(name, *args, &block)
    execute "drop table if exists #{name}"

    create_table(name, *args) do |t|
      t.string :name
      t.integer :size
    end

    add_index name, :name, unique: true
    add_index name, :size, unique: true
  end

  def self.up
    if ENV['MYSQL']
      ActiveRecord::Base.establish_connection('test_mysql')
      recreate_table(:mysql_models)
    end

    if ENV['POSTGRES']
      ActiveRecord::Base.establish_connection(ENV['POSTGRES_URL'] || 'test_postgresql')
      recreate_table(:postgresql_models)
    end

    ActiveRecord::Base.establish_connection('test_sqlite3')
    recreate_table(:sqlite3_models)
  end
end

ActiveRecord::Migration.verbose = false
CreateAllTables.up


module TestModel
  extend ActiveSupport::Concern

  included do
    validates_uniqueness_of :name, rescue_from_duplicate: true
    validates_uniqueness_of :size
  end
end

if ENV['MYSQL']
  class MysqlModel < ActiveRecord::Base
    include TestModel

    establish_connection 'test_mysql'
  end
end

if ENV['POSTGRES']
  class PostgresqlModel < ActiveRecord::Base
    include TestModel

    establish_connection ENV['POSTGRES_URL'] || 'test_postgresql'
  end
end

class Sqlite3Model < ActiveRecord::Base
  include TestModel

  establish_connection 'test_sqlite3'
end

Models = [
  Sqlite3Model
]
Models << MysqlModel if defined?(MysqlModel)
Models << PostgresqlModel if defined?(PostgresqlModel)


RSpec.configure do |config|
  config.before :each do
    Models.each(&:delete_all)
  end
end
