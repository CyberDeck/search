class Entry < ApplicationRecord
  include Search
  scope :search, ->(what) { where(Searchable::parse([Entry.arel_table[:name], Entry.arel_table[:description]], [Entry.arel_table[:other], Entry.arel_table[:value]], what)) }
end
