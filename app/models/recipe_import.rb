# Builds a Recipe from the JSON the convert-recipe skill produces
# (extractor meta + transcript + Claude's parsed recipe, flattened).
class RecipeImport
  class Duplicate < StandardError
    attr_reader :recipe

    def initialize(recipe)
      @recipe = recipe
      super("recipe for video #{recipe.video_id} already exists")
    end
  end

  RECIPE_FIELDS = %w[title servings total_time source_url video_id creator caption transcript].freeze
  INGREDIENT_FIELDS = %w[quantity unit item note estimated].freeze

  def initialize(payload, cover: nil, overwrite: false)
    @payload = payload.to_h.stringify_keys
    @cover = cover
    @overwrite = overwrite
  end

  def call
    recipe = find_or_initialize
    Recipe.transaction do
      recipe.ingredients.destroy_all
      recipe.steps.destroy_all
      recipe.assign_attributes(@payload.slice(*RECIPE_FIELDS))
      recipe.notes = Array(@payload["notes"]).map(&:to_s)
      Array(@payload["ingredients"]).each do |row|
        recipe.ingredients.build(row.to_h.stringify_keys.slice(*INGREDIENT_FIELDS).transform_values { |v| v.is_a?(Numeric) ? v.to_s : v })
      end
      Array(@payload["steps"]).each { |body| recipe.steps.build(body: body.to_s) }
      recipe.cover.attach(@cover) if @cover
      recipe.save!
    end
    recipe
  end

  private

  def find_or_initialize
    video_id = @payload["video_id"].presence
    existing = video_id && Recipe.find_by(video_id: video_id)
    raise Duplicate, existing if existing && !@overwrite
    existing || Recipe.new
  end
end
