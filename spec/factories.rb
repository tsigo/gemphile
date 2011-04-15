require 'factory_girl'

Factory.define :repository do |f|
  f.sequence(:owner) { |n| "owner#{n}" }
  f.sequence(:name)  { |n| "repo#{n}" }
end