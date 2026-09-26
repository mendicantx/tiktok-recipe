require "test_helper"

class ApiRecipesTest < ActionDispatch::IntegrationTest
  TOKEN = Rails.application.credentials.recipes_api_token

  PAYLOAD = {
    title: "Test Rice", video_id: "123", creator: "someone", source_url: "https://www.tiktok.com/@someone/video/123",
    transcript: "hello", caption: "caption", notes: [ "a note" ], steps: [ "Cook it.", "Eat it." ],
    ingredients: [ { quantity: "1", unit: "cup", item: "rice", note: nil, estimated: false },
                   { quantity: nil, unit: nil, item: "salt", note: "to taste", estimated: true } ]
  }.freeze

  def post_recipe(payload = PAYLOAD, token: TOKEN, **extra)
    post api_recipes_path, params: { payload: payload.to_json, **extra },
                           headers: { "Authorization" => "Bearer #{token}" }
  end

  test "rejects a missing or wrong token" do
    post api_recipes_path, params: { payload: PAYLOAD.to_json }
    assert_response :unauthorized
    post_recipe(token: "wrong")
    assert_response :unauthorized
  end

  test "creates a recipe with ordered ingredients, steps and cover" do
    cover = fixture_file_upload("cover.jpg", "image/jpeg")
    post_recipe(cover: cover)
    assert_response :created

    recipe = Recipe.find(response.parsed_body["id"])
    assert_equal %w[rice salt], recipe.ingredients.map(&:item)
    assert_equal [ 1, 2 ], recipe.steps.map(&:position)
    assert recipe.ingredients.last.estimated?
    assert_equal [ "a note" ], recipe.notes
    assert recipe.cover.attached?
  end

  test "refuses duplicates unless overwrite is set" do
    post_recipe
    post_recipe(PAYLOAD.merge(title: "Changed"))
    assert_response :conflict

    post_recipe(PAYLOAD.merge(title: "Changed"), overwrite: "1")
    assert_response :created
    assert_equal 1, Recipe.count
    assert_equal "Changed", Recipe.sole.title
    assert_equal 2, Recipe.sole.ingredients.count
  end

  test "rejects a recipe without a title" do
    post_recipe(PAYLOAD.merge(title: ""))
    assert_response :unprocessable_content
  end
end
