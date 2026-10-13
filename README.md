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

### PostgreSQL-compatible duplicate errors without DETAIL

For PostgreSQL-compatible servers, including YugabyteDB YSQL, a unique violation
may report a constraint name without the `DETAIL: Key (...)` column list. In that
case, the gem matches the reported name exactly against the model table's schema
cache indexes. Only a unique index with a non-empty list of columns can identify
a configured handler; expression indexes and unknown names leave the original
exception unhandled. When `DETAIL` is present, its column list still takes precedence.

The fallback does not guess physical partition index names. Applications whose
reported physical names differ from their schema cache names must provide their
own exact mapping to the appropriate schema index and handler columns.

A cold schema cache can query the database during this lookup. If that lookup
raises `ActiveRecord::StatementInvalid` or `ActiveRecord::ConnectionNotEstablished`,
the gem leaves the original duplicate exception unhandled rather than replacing
it with the metadata error or adding a validation error.

This is error classification, not transaction recovery: even when warm metadata
allows the gem to add an error and return `false`, a PostgreSQL-compatible
transaction aborted by the failed statement remains aborted. This fallback does
not introduce savepoints or make subsequent database statements safe.

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
