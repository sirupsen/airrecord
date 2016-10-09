# Airtable

```ruby
gem 'airrecord', github: "Sirupsen/airrecord"
```

```ruby
teas = Airtable.table("key1", "app1", "Teas")

teas.records.each do |record|
  puts "#{record.id}: #{record[:name]}"
end

p teas.find(teas.records.first.id)
```

```ruby
class Brew < Airtable::Table
  self.api_key = "key1"
  self.base_key = "app1"
  self.table_name = "Hot Brews"

  belongs_to :tea, class: 'Tea', column: 'Tea'
end

class Tea < Airtable::Table
  self.api_key = "key1"
  self.base_key = "app1"
  self.table_name = "Teas"

  has_many :hot_brews, class: 'Brew', column: "Hot Brews"

  def location
    [self[:village], self[:country], self[:region]].compact.join(", ")
  end
end

tea = Tea.all[2]
brew = tea[:hot_brews].first
brew[:tea].id == tea.id

tea = Tea.new(Name: "omg tea", Type: ["Oolong"])
tea.create

tea[:name] = "super omg tea"
tea.save

tea = Tea.find(tea.id)
puts tea[:name]
# => "super omg tea"

brew = Brew.new(Tea: [tea], Rating: "3 - Fine")
brew.create

tea = Tea.find(tea.id)
puts tea[:hot_brews].first[:rating]
# => "3 - Fine"
```
