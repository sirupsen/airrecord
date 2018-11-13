# 1.0.0 (unreleased)

* 1.0.0 will introduce breaking changes, including removing support for symbols. To update, change snake-case symbols to their correct column names (for example, `record["First Name"]` instead of `record[:first_name]`)
* Implement associations as instance methods, e.g.
    ```ruby
    tea.brews #=> [<Brew>, <Brew>] returns associated models
    tea["Brews"] #=> ["rec456", "rec789"] returns a raw Airtable field
    ```
* Automatically throttle client calls to Airtable's API limit of 5 requests per second.
* Fix sorting by multiple fields
* Report `User-Agent` as `Airrecord`.
* Dates that are formed `\d{4}-\d{2}-\d{2}` are no longer auto-parsed. Define a helper instead.

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
