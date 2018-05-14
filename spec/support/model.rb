require "active_record"
require "json"
require "yaml"

CONNECTIONS = {
  test_sqlite3: {
    adapter: "sqlite3",
    database: "/tmp/rescue_from_duplicate.db",
  },
  test_postgresql: {
    adapter: "postgresql",
    database: "rescue_from_duplicate",
    username: "test",
    password: "test",
    host: "127.0.0.1",
    port: "29292",
  },
  test_mysql: {
    adapter: "mysql2",
    database: "rescue_from_duplicate",
    username: "test",
    password: "test",
    host: "127.0.0.1",
    port: "29291",
  },
}
class CreateAllTables < ActiveRecord::Migration[5.2]
  def self.recreate_table(name, *args, &block)
    execute "drop table if exists #{name}"

    create_table(name, *args) do |t|
      t.integer :relation_id
      t.string :handle

      t.string :name
      t.integer :size
    end

    add_index name, [:relation_id, :handle], unique: true
    add_index name, :name, unique: true
    add_index name, :size, unique: true

    # Tables for parent-shild tests
    execute "drop table if exists clients"
    execute "drop table if exists employees"
    execute "drop table if exists companies"

    create_table :companies do |t|
    end

    create_table :employees do |t|
      t.string :name
      t.references :company, foreign_key: true
    end

    add_index :employees, :name, unique: true

    create_table :clients do |t|
      t.string :address
      t.references :employee, foreign_key: true
    end

    add_index :clients, :address, unique: true

    # Tables for many-to-many tests
    execute "drop table if exists memberships"
    execute "drop table if exists items"
    execute "drop table if exists subsets"

    create_table :items do |t|
    end

    create_table :subsets do |t|
    end

    create_table :memberships do |t|
      t.references :item, foreign_key: true
      t.references :subset, foreign_key: true
    end

    add_index :memberships, [:item_id, :subset_id], unique: true
  end

  def self.up
    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_mysql))
    recreate_table(:mysql_models)

    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_postgresql))
    recreate_table(:postgresql_models)

    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_sqlite3))
    recreate_table(:sqlite3_models)
  end
end

ActiveRecord::Migration.verbose = false
CreateAllTables.up


module TestModel
  def self.included(base)
    base.rescue_from_duplicate(:handle, scope: :relation_id, message: "handle must be unique for this relation")

    base.validates(:name, uniqueness: { rescue_from_duplicate: true }, allow_nil: true)
    base.validates(:size, uniqueness: { rescue_from_duplicate: true }, allow_nil: true)
  end
end

class MysqlModel < ActiveRecord::Base
  include TestModel

  establish_connection(CONNECTIONS.fetch(:test_mysql))
end

class PostgresqlModel < ActiveRecord::Base
  include TestModel

  establish_connection(CONNECTIONS.fetch(:test_postgresql))
end

class Sqlite3Model < ActiveRecord::Base
  include TestModel

  establish_connection(CONNECTIONS.fetch(:test_sqlite3))
end

Models = [
  Sqlite3Model,
  MysqlModel,
  PostgresqlModel,
]


RSpec.configure do |config|
  config.before :each do
    Models.each(&:delete_all)
  end
end
