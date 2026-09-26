# Read-only. Recipes are added only through Api::RecipesController (the convert-recipe skill).
class RecipesController < ApplicationController
  def index
    @query = params[:q]
    @recipes = Recipe.search(@query).with_attached_cover.order(created_at: :desc)
  end

  def show
    @recipe = Recipe.find(params[:id])
  end
end
