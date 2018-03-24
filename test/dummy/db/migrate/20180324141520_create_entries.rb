class CreateEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :entries do |t|
      t.string :name
      t.string :description
      t.integer :value
      t.decimal :other

      t.timestamps
    end
  end
end
