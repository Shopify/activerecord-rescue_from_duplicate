# ActiveRecord - RescueFromDuplicate

[![Build Status](https://travis-ci.org/Shopify/activerecord-rescue_from_duplicate.png?branch=master)](https://travis-ci.org/Shopify/activerecord-rescue_from_duplicate)

This gem will rescue SQL errors when trying to insert records that fail uniqueness validation.

It complements `:validates_uniqueness_of` and will add appropriate errors.

Additionally, a macro allows you to assume that the record will be unique and rescue gracefully otherwise.

Tested with:

- MySQL, PostgreSQL, Sqlite3

**Note:**

* `after_validation`, `before_save`, `before_create` will have been run. Make sure they don't have undesired side-effects.
* Unlike failed validation, `ActiveRecord::RecordNotSaved` will be raised when using `create!`, `save!` or other `!` methods.

## Usage

### With validation

Add the `rescue_from_duplicate: true` to any regular uniqueness validation.

This will use the Rails standard validation, performing a `SELECT` to ensure the record is valid. In the case of a race condition, an error will be added to the model, and no exception will be thrown.

```ruby
class ModelWithUniquenessValidator < ActiveRecord::Base
  validates_uniqueness_of :name, scope: :shop_id, rescue_from_duplicate: true
end
```

If two of this statement go in at the same time, and the original validation on uniqueness of name passes, the DBMS will raise an duplicate record error.

```ruby
a = ModelWithUniquenessValidator.create(name: "name")

# in a different thread, causing race condition
b = ModelWithUniquenessValidator.create(name: "name")

a.persisted? #=> true
b.persisted? #=> false
b.errors[:name] #=> ["has already been taken"]
```

### Without validation

You can use this if you don't need to check that the record is unique before attempting to insert it. It will not add any validation to the model, but it will add an error if the persistance fails.

```ruby
class ModelWithUniqueToken < ActiveRecord::Base
  rescue_from_duplicate :token, scope: :shop_id
end
```

### Naming the index

By default the gem picks the handler whose attribute and scope columns equal the columns of the violated index. When the index has other columns than the declaration (an extra partitioning column, a partial index, an expression), name the index with `index_name:` and the gem matches the violated index by name first. `index_name:` takes one name or an array of names, for a rule that more than one index enforces (on different databases, or during a migration):

```ruby
class ModelWithNamedIndex < ActiveRecord::Base
  validates :code, uniqueness: { scope: :shop_id, rescue_from_duplicate: { index_name: "index_models_on_shop_id_and_code_and_region" } }
  rescue_from_duplicate :token, scope: :shop_id, index_name: ["index_models_unique_token", "index_models_on_shop_id_and_token"]
end
```

On a partitioned PostgreSQL table, the error names the index of the partition that holds the row, not the index of the parent table. List the partition index names too.

If no handler names the violated index, the gem falls back to matching columns. SQLite names the index only when an expression index is violated. For a column index it reports only the columns, so there only column matching applies.

`RescueFromDuplicate.missing_unique_indexes` treats a handler that names indexes as covered when a unique index or the primary key has one of those names, or when a unique index has its columns. An expression index can only be matched by name.

## Installation

Add this line to your application's Gemfile:

    gem 'activerecord-rescue_from_duplicate'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activerecord-rescue_from_duplicate

## Development Setup

Install:

- Have Docker installed
- Clone the repo
- `docker-compose up -d`

Run tests:

```
rspec
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
