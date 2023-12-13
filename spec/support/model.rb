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
    port: "5432",
  },
  test_mysql: {
    adapter: "mysql2",
    database: "rescue_from_duplicate",
    username: "test",
    password: "test",
    host: "127.0.0.1",
    port: "3306",
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

    base.validates(:name, uniqueness: { rescue_from_duplicate: true, case_sensitive: true }, allow_nil: true)
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
