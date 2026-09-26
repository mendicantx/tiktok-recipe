require "test_helper"

class RecipesFlowTest < ActionDispatch::IntegrationTest
  def create_recipe(title, ingredient: "salt", estimated: false)
    Recipe.new(title: title, creator: "cook", transcript: "words", notes: [ "n" ]).tap do |r|
      r.ingredients.build(item: ingredient, estimated: estimated)
      r.steps.build(body: "Boil.")
      r.save!
    end
  end

  test "index lists and searches recipes by title and ingredient" do
    create_recipe("Grandma's Pancakes", ingredient: "flour")
    create_recipe("Soup")

    get root_path
    assert_select "h2", count: 2
    get recipes_path(q: "flour")
    assert_select "h2", text: "Grandma's Pancakes"
    assert_select "h2", count: 1
    get recipes_path(q: "nothing-matches")
    assert_select "h2", count: 0
  end

  test "show page renders imported fields with no editing controls" do
    recipe = create_recipe("Soup", estimated: true)
    get recipe_path(recipe)
    assert_response :success
    assert_select "h1", "Soup"
    assert_match "Quantity not stated", response.body
    assert_select "form[method=post]", count: 0
    assert_select "a[href=?]", "/recipes/new", count: 0
  end

  test "pages carry link-preview tags with a directly fetchable cover image" do
    recipe = create_recipe("Soup")
    recipe.cover.attach(fixture_file_upload("cover.jpg", "image/jpeg"))

    get recipe_path(recipe)
    assert_select "meta[property='og:title'][content='Soup']"
    assert_select "meta[property='og:description'][content*='From @cook']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    image_url = css_select("meta[property='og:image']").first["content"]
    assert_match %r{\Ahttp://www\.example\.com/rails/active_storage/}, image_url

    get image_url
    assert_response :success, "og:image must serve the file itself, not a redirect"
    assert_equal "image/jpeg", response.media_type

    get root_path
    assert_select "meta[property='og:title'][content='Recipe Box']"
    assert_select "meta[property='og:image']", count: 1
  end

  test "the site is read-only: new, create, edit, update and delete are not routable" do
    recipe = create_recipe("Soup")

    get "/recipes/new"
    assert_response :not_found
    post "/recipes", params: { recipe: { title: "Spam" } }
    assert_response :not_found
    get "/recipes/#{recipe.id}/edit"
    assert_response :not_found
    patch "/recipes/#{recipe.id}", params: { recipe: { title: "x" } }
    assert_response :not_found
    delete "/recipes/#{recipe.id}"
    assert_response :not_found

    assert_equal [ "Soup" ], Recipe.pluck(:title)
  end
end
