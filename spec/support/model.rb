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
  def self.recreate_tables
    execute "drop table if exists parents"
    execute "drop table if exists children"

    create_table :parents do |t|
      t.integer :relation_id
      t.string :handle

      t.string :name
      t.integer :size
    end

    add_index :parents, [:relation_id, :handle], unique: true
    add_index :parents, :name, unique: true
    add_index :parents, :size, unique: true


    create_table :children do |t|
      t.belongs_to :parent
      t.string :name
    end

    add_index :children, [:parent_id, :name], unique: true
  end

  def self.recreate_child_table(name, parent_name, *args)
    execute "drop table if exists #{name}"

    create_table(name, *args) do |t|
      t.integer parent_name
      t.string :name
    end

    add_index name, [parent_name, :name], unique: true
  end

  def self.up
    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_mysql))
    recreate_tables

    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_postgresql))
    recreate_tables

    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_sqlite3))
    recreate_tables
  end
end

ActiveRecord::Migration.verbose = false
CreateAllTables.up


module TestModel
  def self.included(base)
    base.table_name = :parents
    base.rescue_from_duplicate(:handle, scope: :relation_id, message: "handle must be unique for this relation")

    base.validates(:name, uniqueness: { rescue_from_duplicate: true }, allow_nil: true)
    base.validates(:size, uniqueness: { rescue_from_duplicate: true }, allow_nil: true)
  end
end

module TestChildModel
  def self.included(base)
    base.table_name = :children
    base.validates(:name, uniqueness: { rescue_from_duplicate: true, scope: :parent_id }, allow_nil: true)
  end
end


class MysqlModel < ActiveRecord::Base
  include TestModel

  has_many(:children, class_name: 'MysqlChildModel', foreign_key: :parent_id)

  establish_connection(CONNECTIONS.fetch(:test_mysql))
end

class MysqlChildModel < ActiveRecord::Base
  include TestChildModel

  belongs_to(:parent, class_name: 'MysqlModel')

  establish_connection(CONNECTIONS.fetch(:test_mysql))
end


class PostgresqlModel < ActiveRecord::Base
  include TestModel

  has_many(:children, class_name: 'PostgresqlChildModel', foreign_key: :parent_id)

  establish_connection(CONNECTIONS.fetch(:test_postgresql))
end

class PostgresqlChildModel < ActiveRecord::Base
  include TestChildModel

  belongs_to(:parent, class_name: 'PostgresqlModel')

  establish_connection(CONNECTIONS.fetch(:test_postgresql))
end

class Sqlite3Model < ActiveRecord::Base
  include TestModel

  has_many(:children, class_name: 'Sqlite3ChildModel', foreign_key: :parent_id)

  establish_connection(CONNECTIONS.fetch(:test_sqlite3))
end

class Sqlite3ChildModel < ActiveRecord::Base
  include TestChildModel

  belongs_to(:parent, class_name: 'Sqlite3Model')

  establish_connection(CONNECTIONS.fetch(:test_sqlite3))
end

Models = [
  Sqlite3Model,
	Sqlite3ChildModel,
  MysqlModel,
  MysqlChildModel,
  PostgresqlModel,
  PostgresqlChildModel
]


RSpec.configure do |config|
  config.before :each do
    Models.each(&:delete_all)
  end
end
