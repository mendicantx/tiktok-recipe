class CreateRecipes < ActiveRecord::Migration[8.0]
  def change
    create_table :recipes do |t|
      t.string :title, null: false
      t.string :servings
      t.string :total_time
      t.string :source_url
      t.string :video_id
      t.string :creator
      t.text :caption
      t.text :transcript
      t.json :notes, null: false, default: []

      t.timestamps
    end
    add_index :recipes, :video_id, unique: true
  end
end
