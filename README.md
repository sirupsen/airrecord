# Airrecord

Airrecord is an alternative Airtable Ruby libary to
[`airtable-ruby`](https://github.com/airtable/airtable-ruby). Airrecord attempts
to enforce a more [database-like API to
Airtable](http://sirupsen.com/minimum-viable-airtable/).

You can add this line to your Gemfile to use Airrecord:

```ruby
gem 'airrecord'
```

A quick example to give an idea of the API that Airrecord provides:

```ruby
Airrecord.api_key = "key1"

class Tea < Airrecord::Table
  self.base_key = "app1"
  self.table_name = "Teas"

  has_many :brews, class: 'Brew', column: "Brews"

  def location
    [self[:village], self[:country], self[:region]].compact.join(", ")
  end
end

class Brew < Airrecord::Table
  self.base_key = "app1"
  self.table_name = "Brews"

  belongs_to :tea, class: 'Tea', column: 'Tea'
end

teas = Tea.all
tea = teas.first
tea[:country] # access atribute
tea.location # instance methods
tea[:brews] # associated brews
```

An ad-hoc API more in tune with the alternative API wrapper is also available:

```ruby
teas = Airrecord.table("key1", "app1", "Teas")
teas.all.each do |record|
  puts "#{record.id}: #{record[:name]}"
end
teas.find("rec3838")
```

## Documentation

### Authentication

To obtain your API client, navigate to the [Airtable's API
page](https://airtable.com/api), select your base and obtain your API key and
application token.

![](https://cloud.githubusercontent.com/assets/97400/23580721/a0815df4-00bb-11e7-9abf-140a01625678.png)

You can provide a global API key with:

```ruby
Airrecord.api_key = "your api key"
```

The app token has to be set on the definitions of the tables (see API below).
You can override the API key per table.

### Table

The Airrecord API is centered around definitions of `Airrecord::Table` from
which the definitions of your tables inherit. This is analogous to
`ActiveRecord::Base`. For example, we may have a Base to track teas we have
tried.

```ruby
Airrecord.api_key = "your api key" # see authentication section

class Tea < Airrecord::Table
  self.base_key = "app1"
  self.table_name = "Teas"

  def location
    [self[:village], self[:country], self[:region]].compact.join(", ")
  end
end
```

This gives us a class that maps to records in a table. Class methods are
available to fetch records on the table.

### Listing Records

Retrieval of multiple records is done through `#all`. To get all records in a
table:

```ruby
Tea.all # array of Tea instances
```

You can use all options supported by the API (they are documented on the [API page for your base](https://airtable.com/api)). By default `#all` will traverse all pages, see below on how to control pagination.

To use `filterbyFormula` to filter returned records:

```ruby
# Retrieve all teas from China
Tea.all(filter: "{Country} == "China")

# Retrieve all teas created in the past week
Tea.all(filter: "DATETIME_DIFF(CREATED_TIME(), TODAY(), 'days') < 7")
```

This filtering can, of course, also be done in Ruby directly after calling
`#all` without `filter`, however, it may be more efficient to let Airtable
filter if you have a lot of records.

You can use `view` to only fetch records from a specific view. This is less
ad-hoc than `filterByFormula`:

```ruby
# Retrieve all teas in the green tea view
Tea.all(view: "Green")

# Retrieve all Japanese teas
Tea.all(view: "Japan")
```

The `sort` option can be used to sort results returned from the Airtable API.

```ruby
# Sort teas by the Name column in ascending order
Tea.all(sort: { Name: "asc" })

# Sort teas by Type (green, black, oolong, ..) in descending order
Tea.all(sort: { Type: "desc" })

# Sort teas by price in descending order
Tea.all(sort: { Price: "desc" })
```

Note again that the key _must_ be the full column name. Snake-cased variants do
not work here.

As mentioned above, by default Airrecord will return results from all pages.
This can be slow if you have 1000s of records. You may wish to use the `view`
and/or `filter` option to sort in the results early, instead of doing 10s of
calls. Airrecord will _always_ fetch the maximum possible amount of records
(100). This means that fetching 1,000 records will take 10 (at least) roundtrips. You can disable pagination (which fetches the first page) by passing `paginate: false`. This is especially useful if you're looking to fetch a set of recent records from a view or formula in tandem with a `sort`:

```ruby
# Only fetch the first page. Sorting is undefined.
Tea.all(paginate: false)

# Give me only the most recent teas
Tea.all(sort: { "Created At": "desc" }, paginate: false)
```

### Creating

Creating a new record is done through `#create`.

```ruby
tea = Tea.new("Name" => "Feng Gang", "Type" => "Green", "Country" => "China")
tea.create # creates the record
tea.id # id of the new record
tea[:name] # "Feng Gang", accessed through snake-cased name
```

Note that when instantiating the new record the column names (keys of the passed
named parameters) need to match the exact column names in Airtable, otherwise
Airrecord will throw an error that no column matches it.

In the future I hope to provide more convient names for these (snake-cased),
however, this is error-prone without a proper schema API from Airtable which has
still not been released.

### Updating

Updating a record is done by changing the attributes and persistent to
Airtable with `#save`.

```ruby
tea = Tea.find("someid")
tea[:name] = "Feng Gang Organic"

# Since the Village column is not set, we do not have access to a snake-cased
variant since the mapping is not determined. For all we know, the correct column
name could be "VilLlaGe". Therefore, we must use the proper column name.
tea["Village"] = "Feng Gang"

tea.save # persist to Airtable
```

### Deleting

An instantiated record can be deleted through `#destroy`:

```ruby
tea = Tea.find("rec839")
tea.destroy # deletes record
```

### Associations

Airrecord supports managing associations between tables by linking
`Airrecord::Table` classes. To continue with our tea example, we may have
another table in the base to track brews of a specific tea (temperature,
steeping time, rating, ..). A tea thus has many brews:

```ruby
class Tea < Airrecord::Table
  self.base_key = "app1"
  self.table_name = "Teas"

  has_many :brews, class: 'Brew', column: "Brews"
end

class Brew < Airrecord::Table
  self.base_key = "app1"
  self.table_name = "Brews"

  belongs_to :tea, class: 'Tea', column: 'Tea'
end
```

This gives us access to a bunch of convenience methods to handle the assocation
between the two tables. Note that the two tables need to be in the same base
(i.e. have the same base key) otherwise this will _not_ work as Airtable does
_not_ support associations across Bases.

### Retrieving associated records

To retrieve records from associations to a record:

```ruby
tea = Tea.find('rec84')
tea[:brews] # brews associated with tea
```

This in turn works the other way too:

```ruby
brew = Brew.find('rec849')
brew[:tea] # the associated tea instance
```

### Creating associated records

You can easily associate records with each other:

```ruby
tea = Tea.find('rec849829')
# This will create a brew associated with the specific tea
Brew.create("Tea" => tea, "Temperature" => "80", "Time" => "4m", "Rating" => "5")
```

### Ad-hoc API

Airrtable provides a simple, ad-hoc API that will instantiate an anonymous
`Airrecord::Table` for you on the fly with the configured key, app, and table.

```ruby
teas = Airrecord.table("key1", "app1", "Teas")

teas.all.each do |record|
  puts "#{record.id}: #{record[:name]}"
end

p teas.find(teas.records.first.id)
```

### Snake-cased helper methods

When retrieving an existing record from Airtable, snake-cased helper names are
available to index attributes. These are _only_ available on retrieved records,
and _only_ if the column was set. If it's `nil`, it will not exist. That means
if you want to set column that has a `nil` value for a column type, you'll have
to fully type it out.

## Contributing

Contributions will be happily accepted in the form of Github Pull Requests!

* Please ensure CI is passing before submitting your pull request for review.
* Please provide tests that fail without your change.
