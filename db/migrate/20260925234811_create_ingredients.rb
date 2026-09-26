class CreateIngredients < ActiveRecord::Migration[8.0]
  def change
    create_table :ingredients do |t|
      t.references :recipe, null: false, foreign_key: true
      t.integer :position
      t.string :quantity
      t.string :unit
      t.string :item, null: false
      t.string :note
      t.boolean :estimated, null: false, default: false

      t.timestamps
    end
  end
end
