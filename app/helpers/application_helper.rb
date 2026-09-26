module ApplicationHelper
  SITE_NAME = "Recipe Box".freeze

  # Open Graph / Twitter tags so shared links (iMessage, Slack, etc.) show a preview.
  def social_meta_tags(title:, description:, image: nil)
    image_url = rails_storage_proxy_url(image) if image&.attached?
    tags = {
      "og:site_name" => SITE_NAME,
      "og:type" => "website",
      "og:title" => title,
      "og:description" => description,
      "og:url" => request.original_url,
      "og:image" => image_url,
      "twitter:card" => image_url ? "summary_large_image" : "summary"
    }.compact

    safe_join([ tag.meta(name: "description", content: description) ] + tags.map { |key, value|
      key.start_with?("twitter:") ? tag.meta(name: key, content: value) : tag.meta(property: key, content: value)
    }, "\n")
  end

  def recipe_summary(recipe)
    parts = [ recipe.creator && "From @#{recipe.creator}", recipe.total_time, recipe.servings ].compact_blank
    items = recipe.ingredients.map(&:item).first(6)
    [ parts.join(" · "), items.any? ? "#{items.join(', ')}#{'…' if recipe.ingredients.size > 6}" : nil ].compact_blank.join(". ")
  end
end
