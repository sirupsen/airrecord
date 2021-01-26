# 1.0.6

* Support Ruby 3 (#79)

# 1.0.5

* Allow Faraday 1.0 (#70)

# 1.0.4

* Correctly set `created_at` on `#find` (#68)

# 1.0.3

* Allow passing optional parameters, e.g. `typecast: true`. (#67)

# 1.0.2

* When a `has_one` or `belongs_to` association is empty, return `nil` instead of
  a blank record (#51)

* When a `has_many` association is empty, do not make a network call to the
  associated table

* Relax dependency on `net-http-persistent` to allow latest (#57)

# 1.0.1

* Support JRuby 9.0 and CRuby 2.2 (#47)
* Fix $stderr warnings in CRurby > 2.3 (#46)

# 1.0.0

* 1.0.0 introduces breaking changes, including removing support for symbols and
  implementing associations as instance methods. To upgrade:
  1. Change snake-case symbols to their correct column names:
    `record["First Name"]` instead of `record[:first_name]`)
  2. Change your association calls to use instance methods instead of `[]`:
      ```ruby
      class Tea < Airrecord::Table
        has_many :brews, class: "Brew", column: "Brews"
      end
      tea[:brews] #=> Error, no longer supported
      tea.brews #=> [<Brew>, <Brew>] returns associated Brew instances
      tea["Brews"] #=> ["rec456", "rec789"] returns a raw Airtable field
      ```
  3. Dates that are formed `\d{4}-\d{2}-\d{2}` are no longer auto-parsed. Define a helper instead.
* Automatically throttle client calls to Airtable's API limit of 5 requests per second.
* Fix sorting by multiple fields
* Report `User-Agent` as `Airrecord`.

# 0.2.5

* Deprecate using symbols instead of strings

# 0.2.4

* Don't flag as dirty if change is equal

# 0.2.3

* Allow single associations (#12)
* Allow passing `maxRecord` and `pageSize` (#17)

# 0.2.2

* Require URI to avoid dependency errors

# 0.2.1

* Added comparison operator (#9)
