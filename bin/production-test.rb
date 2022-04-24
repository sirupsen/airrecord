require 'airrecord'

p Faraday::VERSION

Tea = Airrecord.table(
  ENV["AIRTABLE_TOKEN"],
  "appZJC9q8TBYPDF7j",
  "Teas"
)

# p Tea.all
