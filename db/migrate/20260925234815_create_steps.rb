class CreateSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :steps do |t|
      t.references :recipe, null: false, foreign_key: true
      t.integer :position
      t.text :body, null: false

      t.timestamps
    end
  end
end
