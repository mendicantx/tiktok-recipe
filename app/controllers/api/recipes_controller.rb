module Api
  # POST /api/recipes  (Authorization: Bearer <token>)
  #   multipart: payload=<recipe JSON string>, cover=<image file>, overwrite=1 (optional)
  #   or a plain JSON body with the recipe fields (no cover)
  class RecipesController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate

    def create
      recipe = RecipeImport.new(payload, cover: params[:cover], overwrite: params[:overwrite].present?).call
      render json: { id: recipe.id, url: recipe_url(recipe) }, status: :created
    rescue RecipeImport::Duplicate => e
      render json: { error: e.message, url: recipe_url(e.recipe) }, status: :conflict
    rescue ActiveRecord::RecordInvalid, JSON::ParserError => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def payload
      if params[:payload].present?
        JSON.parse(params[:payload].respond_to?(:read) ? params[:payload].read : params[:payload])
      else
        request.request_parameters.except("cover", "overwrite")
      end
    end

    def authenticate
      expected = Rails.application.credentials.recipes_api_token.presence || ENV["RECIPES_API_TOKEN"].presence
      authenticate_or_request_with_http_token do |token, _|
        expected && ActiveSupport::SecurityUtils.secure_compare(token, expected)
      end
    end
  end
end
