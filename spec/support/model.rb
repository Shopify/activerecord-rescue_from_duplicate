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

      t.string :namespace
      t.string :key
    end

    add_index name, [:relation_id, :handle], unique: true
    add_index name, :name, unique: true
    add_index name, :size, unique: true
  end

  def self.up
    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_mysql))
    recreate_table(:mysql_models)
    recreate_table(:mysql_cpk_models, primary_key: [:namespace, :key])
    recreate_table(:mysql_cpk_no_validator_models, primary_key: [:namespace, :key])

    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_postgresql))
    recreate_table(:postgresql_models)
    recreate_table(:postgresql_cpk_models, primary_key: [:namespace, :key])
    recreate_table(:psql_cpk_no_validator_models, primary_key: [:namespace, :key])

    ActiveRecord::Base.establish_connection(CONNECTIONS.fetch(:test_sqlite3))
    recreate_table(:sqlite3_models)
    recreate_table(:sqlite3_cpk_models, primary_key: [:namespace, :key])
    recreate_table(:sqlite3_cpk_no_validator_models, primary_key: [:namespace, :key])
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

module TestCpkModel
  def self.included(base)
    base.validates(:key, uniqueness: {
      scope: :namespace,
      case_sensitive: false,
      rescue_from_duplicate: true,
      message: "must be unique within this namespace",
    })
  end
end

module TestCpkModelNoValidator
  def self.included(base)
    base.rescue_from_duplicate(:key, scope: :namespace, message: "must be unique within this namespace")
  end
end

class MysqlModel < ActiveRecord::Base
  include TestModel

  establish_connection(CONNECTIONS.fetch(:test_mysql))
end

class MysqlCpkModel < ActiveRecord::Base
  include TestCpkModel

  establish_connection(CONNECTIONS.fetch(:test_mysql))
end

class MysqlCpkNoValidatorModel < ActiveRecord::Base
  include TestCpkModelNoValidator

  establish_connection(CONNECTIONS.fetch(:test_mysql))
end

class PostgresqlModel < ActiveRecord::Base
  include TestModel

  establish_connection(CONNECTIONS.fetch(:test_postgresql))
end

class PostgresqlCpkModel < ActiveRecord::Base
  include TestCpkModel

  establish_connection(CONNECTIONS.fetch(:test_postgresql))
end

class PsqlCpkNoValidatorModel < ActiveRecord::Base
  include TestCpkModelNoValidator

  establish_connection(CONNECTIONS.fetch(:test_postgresql))
end

class Sqlite3Model < ActiveRecord::Base
  include TestModel

  establish_connection(CONNECTIONS.fetch(:test_sqlite3))
end

class Sqlite3CpkModel < ActiveRecord::Base
  include TestCpkModel

  establish_connection(CONNECTIONS.fetch(:test_sqlite3))
end

class Sqlite3CpkNoValidatorModel < ActiveRecord::Base
  include TestCpkModelNoValidator

  establish_connection(CONNECTIONS.fetch(:test_sqlite3))
end

Models = [
  Sqlite3Model,
  Sqlite3CpkModel,
  Sqlite3CpkNoValidatorModel,
  MysqlModel,
  MysqlCpkModel,
  MysqlCpkNoValidatorModel,
  PostgresqlModel,
  PostgresqlCpkModel,
  PsqlCpkNoValidatorModel,
]


RSpec.configure do |config|
  config.before :each do
    Models.each(&:delete_all)
  end
end
