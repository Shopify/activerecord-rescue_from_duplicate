# ActiveRecord - RescueFromDuplicate

This gem will rescue from MySQL and Sqlite errors when trying to insert records that fail uniqueness validation.
PostgreSQL is not supported at the moment because of the errors raised when using prepared statements.

It complements `:validates_uniqueness_of` and will add appropriate errors.

**Note:**

* All `before_*` filters will have been run.
* Unlike failed validation, `ActiveRecord::RecordNotSaved` will be raised when using `create!`, `save!` or other `!` methods.

## Installation

Add this line to your application's Gemfile:

    gem 'activerecord-rescue_from_duplicate'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activerecord-rescue_from_duplicate

## Usage

Add the `:rescue_from_duplicate => true` to any regular uniqueness validation.

```ruby
class ModelWithUniquenessValidator < ActiveRecord::Base
  validates_uniqueness_of :name, :scope => :shop_id, :rescue_from_duplicate => true
end
```

If two of this statement go in at the same time, and the original validation on uniqueness of name passes, the DBMS will raise an duplicate record error.

```ruby
a = ModelWithUniquenessValidator.create(:name => "name")

# in a different thread, causing race condition
b = ModelWithUniquenessValidator.create(:name => "name")

a.persisted? #=> true
b.persisted? #=> false
b.errors[:name] #=> ["has already been taken"]
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
