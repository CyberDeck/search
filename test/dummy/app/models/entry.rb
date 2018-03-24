class Entry < ApplicationRecord
  scope :search, ->(what) { where(Entry.arel_table[:name].matches_any(what)) }
end
