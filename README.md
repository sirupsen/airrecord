# Airtable

```ruby
gem 'airtable', github: "Sirupsen/airtable"
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

  belongs_to :tea, class: 'Tea'
end

class Tea < Airtable::Table
  self.api_key = "key1"
  self.base_key = "app1"
  self.table_name = "Teas"

  has_many :hot_brews, class: 'Brew'

  def location
    [self[:village], self[:country], self[:region]].compact.join(", ")
  end
end

tea = Tea.all[2]
tea.each do |tea|
  puts tea.location
end

brew = tea[:hot_brews].first
```
