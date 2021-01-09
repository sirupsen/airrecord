# Airrecord

Airrecord is an alternative Airtable Ruby libary to
[`airtable-ruby`](https://github.com/airtable/airtable-ruby). Airrecord attempts
to enforce a more [database-like API to
Airtable](http://sirupsen.com/minimum-viable-airtable/). However, there's also
an [ad-hoc API available](https://github.com/sirupsen/airrecord#ad-hoc-api) that
skips the class definitions!

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

  has_many :brews, class: "Brew", column: "Brews"

  def self.chinese
    all(filter: '{Country} = "China"')
  end

  def self.cheapest_and_best
    all(sort: { "Rating" => "desc", "Price" => "asc" })
  end

  def location
    [self["Village"], self["Country"], self["Region"]].compact.join(", ")
  end

  def green?
    self["Type"] == "Green"
  end
end

class Brew < Airrecord::Table
  self.base_key = "app1"
  self.table_name = "Brews"

  belongs_to :tea, class: "Tea", column: "Tea"

  def self.hot
    all(filter: "{Temperature} > 90")
  end

  def done_brewing?
    Time.parse(self["Created At"]) + self["Duration"] > Time.now
  end
end

teas = Tea.all
tea = teas.first
tea["Country"] # access atribute
tea.location # instance methods
tea.brews # associated brews
```

A short-hand API for definitions and more ad-hoc querying is also available:

```ruby
Tea = Airrecord.table("api_key", "app_key", "Teas")

Tea.all.each do |record|
  puts "#{record.id}: #{record["Name"]}"
end

Tea.find("rec3838")
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
    [self["Village"], self["Country"], self["Region"]].compact.join(", ")
  end
end
```

This gives us a class that maps to records in a table. Class methods are
available to fetch records on the table.

### Reading a Single Record

Retrieve a single record via `#find`:
```ruby
tea = Tea.find("someid")
```

### Listing Records

Retrieval of multiple records is usually done through `#all`. To get all records
in a table:

```ruby
Tea.all # array of Tea instances
```

You can use all options supported by the API (they are documented on the [API page for your base](https://airtable.com/api)). By default `#all` will traverse all pages, see below on how to control pagination.

To use `filterbyFormula` to filter returned records:

```ruby
# Retrieve all teas from China
Tea.all(filter: '{Country} = "China"')

# Retrieve all teas created in the past week
Tea.all(filter: "DATETIME_DIFF(CREATED_TIME(), TODAY(), 'days') < 7")

# Retrieve all teas that don't have a country defined
Tea.all(filter: "{Country} = \"\"")
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
Tea.all(sort: { "Name" => "asc" })

# Sort teas by Type (green, black, oolong, ..) in descending order
Tea.all(sort: { "Type" => "desc" })

# Sort teas by price in descending order
Tea.all(sort: { "Price" => "desc" })
```

Note again that the key _must_ be the full column name.

As mentioned above, by default Airrecord will return results from all pages.
This can be slow if you have 1000s of records. You may wish to use the `view`
and/or `filter` option to sort in the results early, instead of doing 10s of
calls. Airrecord will _always_ fetch the maximum possible amount of records
(100). This means that fetching 1,000 records will take 10 (at least) roundtrips. You can disable pagination (which fetches the first page) by passing `paginate: false`. This is especially useful if you're looking to fetch a set of recent records from a view or formula in tandem with a `sort`:

```ruby
# Only fetch the first page. Sorting is undefined.
Tea.all(paginate: false)

# Give me only the most recent teas
Tea.all(sort: { "Created At" => "desc" }, paginate: false)
```

When you know the IDs of the records you want, and you want them in an ad-hoc
order, use `#find_many` instead of `#all`:

```ruby
teas = Tea.find_many(["someid", "anotherid", "yetanotherid"])
#=> [<Tea @id="someid">,<Tea @id="anotherid">, <Tea @id="yetanotherid">]
```

### Creating

Creating a new record is done through `Table.create`.

```ruby
tea = Tea.create("Name" => "Feng Gang", "Type" => "Green", "Country" => "China")
tea.id # id of the new record
tea["Name"] # "Feng Gang"
```

If you need to manipulate a record before saving it, you can use `Table.new`
instead of `create`, then call `#save` when you're ready.

```ruby
tea = Tea.new("Type" => "Green", "Country" => "China")
tea["Name"] = "Feng Gang"
tea.save
```

Note that column names need to match the exact column names in Airtable,
otherwise Airrecord will throw an error that no column matches it.


If you need to include optional request parameters, such as the `typecast` parameter, these can be passed to either `Table.create` or `#save`.
This is also supported when updating existing records with the `#save` method.

```ruby
tea = Tea.create(
  {"Name" => "Feng Gang", "Type" => "Green", "Country" => "China"},
  {"typecast" => true},
)

# Or with the #save method:
tea = Tea.new({"Name" => "Feng Gang", "Type" => "Green"})
tea["Name"] = "Feng Gang"
tea.save("typecast" => true)
```

_Earlier versions of airrecord provided methods for snake-cased column names
and symbols, however this proved error-prone without a proper schema API from
Airtable which has still not been released._

### Updating

Updating a record is done by changing the attributes and persistent to
Airtable with `#save`.

```ruby
tea = Tea.find("someid")
tea["Name"] = "Feng Gang Organic"
tea["Village"] = "Feng Gang"

tea.save # persist to Airtable
```

_Airtable's API doesn't allow you to change attachment's filename. As a workaround you can delete the original attachment and [upload a new one](https://github.com/sirupsen/airrecord#file-uploads) with the original URL and a new filename._

### Deleting

An instantiated record can be deleted through `#destroy`:

```ruby
tea = Tea.find("rec839")
tea.destroy # deletes record
```

### File Uploads

Airtable's API requires you to have uploaded your file to an intermediary and
providing the URL. Unfortunately, it does not allow uploading directly.

```ruby
word = World.find("cantankerous")
word["Pronounciation"] = [{url: "https://s3.ca-central-1.amazonaws.com/word-pronunciations/cantankerous.mp3"}]
word.save
```

S3 is a good place to upload files for Airtable. Airrecord does not support this
directly, but the snippet below may be helpful:

```ruby
# Add this to your gemfile
# Full docs at https://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html
require 'aws-sdk-s3'

Aws.config.update(
  credentials: Aws::Credentials.new(access_key, secret_key) # obtain from AWS
  region: 'ca-central-1', # region
)

s3 = Aws::S3::Client.new
s3.put_object({
  body: File.open("cantankerous.mp3"), # IO object
  bucket: 'word-pronunciations',
  key: 'cantankerous.mp3',
  acl: "public-read",
})
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

  has_many :brews, class: "Brew", column: "Brews"
  has_one :teapot, class: "Teapot", column: "Teapot"
end

class Brew < Airrecord::Table
  self.base_key = "app1"
  self.table_name = "Brews"

  belongs_to :tea, class: "Tea", column: "Tea"
end

class Teapot < Airrecord::Table
  self.base_key = "app1"
  self.table_name = "Teapot"

  belongs_to :tea, class: "Tea", column: "Tea"
end
```

This gives us access to a bunch of convenience methods to handle the assocation
between the two tables. Note that the two tables need to be in the same base
(i.e. have the same base key) otherwise this will _not_ work as Airtable does
_not_ support associations across Bases.

### Retrieving associated records

To retrieve records from associations to a record:

```ruby
tea = Tea.find("rec123")

# record.association returns Airrecord instances
tea.brews #=> [<Brew @id="rec456">, <Brew @id="rec789">]
tea.teapot #=> <Teapot @id="rec012">

# record["Associated Column"] returns the raw Airtable field, an array of IDs
tea["Brews"] #=> ["rec789", "rec456"]
tea["Teapot"] #=> ["rec012"]
```

This in turn works the other way too:

```ruby
brew = Brew.find("rec456")
brew.tea #=> <Tea @id="rec123"> the associated tea instance
brew["Tea"] #=> the raw Airtable field, a single-item array ["rec123"]
```

### Creating associated records

You can easily associate records with each other:

```ruby
tea = Tea.find("rec123")
# This will create a brew associated with the specific tea
brew = Brew.new("Temperature" => "80", "Time" => "4m", "Rating" => "5")
brew.tea = tea
brew.create
```

Alternatively, you can specify association ids directly:

```ruby
tea = Tea.find("rec123")
brew = Brew.new("Tea" => [tea.id], "Temperature" => "80", "Time" => "4m", "Rating" => "5")
brew.create
```

### Ad-hoc API

Airrtable provides a simple, ad-hoc API that will instantiate an anonymous
`Airrecord::Table` for you on the fly with the configured key, app, and table.
This is useful if you require no custom definitions, or you're just playing
around.

```ruby
Tea = Airrecord.table("api_key", "app_key", "Teas")

Tea.all.each do |record|
  puts "#{record.id}: #{record["Name"]}"
end

Tea.find("rec3838")
```

### Throttling

Airtable's API enforces a 5 requests per second limit per client. In most cases,
you won't reach this limit in a single thread but it's possible for some fast
calls. Airrecord automatically enforces this limit. It doesn't use a naive
throttling algorithm that does a `sleep(0.2)` between each call, but rather
keeps a sliding window of when each call was made and will sleep at the end of
the window if requires. This means that bursting is supported.

### Production Middlewares

For production use-cases, it's worth considering adding retries and circuit
breakers to Airrecord. This is _not_ enabled by default. Airrecord uses the
Faraday gem for HTTP. Similar to Rack, you can add middlewares to provide
reusable logic for making HTTP requests.

#### Configuring Retries

Refer to the documentation for [all configuration
options](http://www.rubydoc.info/gems/faraday/0.9.2/Faraday/Request/Retry).

```ruby
Airrecord::Table.client.connection.request :retry,
  max: 5, interval: 1, interval_randomness: 2, backoff_factor: 2,
  exceptions: [...] # It's suggested to be explicit here instead of relying on defaults
```

If you are running background scripts or workers with the sole purpose of
communicating with Airtable, it may be worth retrying on failures. Note that
this may cause the process to sleep for many seconds, so choose your values
carefully.

The `Net::HTTP` library that Faraday uses behind the scenes by default has
opaque exceptions. If you choose to go beyond retrying on timeouts (as is
provided by default by the Retry middleware), I suggest referring to a complete
list of `Net::HTTP` exceptions, such as [this
one](https://github.com/Shopify/semian/blob/master/lib/semian/net_http.rb#L35-L44).

### Circuit Breaker

If you're calling Airtable in an application and want to avoid hanging processes
when Airtable is unavailable, we strongly recommend configuring [circuit
breakers](https://github.com/Shopify/semian#circuit-breaker). This is a
mechanism that after `threshold` failures, it'll start failing immediately
instead of waiting until the timeout. This can avoid outages where all workers
are hung trying to talk to a service that will never return, instead of serving
useful fallbacks or requests that don't rely on the service. Failing fast is
paramount for building reliable systems.

You can configure a middleware such as
[`faraday_middleware-circuit_breaker`](https://github.com/textmaster/faraday_middleware-circuit_breaker):

```ruby
Airrecord::Table.client.connection.request :circuit_breaker,
  timeout: 20, threshold: 5
```

## Contributing

Contributions will be happily accepted in the form of Github Pull Requests!

* Please ensure CI is passing before submitting your pull request for review.
* Please provide tests that fail without your change.
