class Recipe < ApplicationRecord
  has_many :ingredients, -> { order(:position) }, dependent: :destroy, inverse_of: :recipe
  has_many :steps, -> { order(:position) }, dependent: :destroy, inverse_of: :recipe
  has_one_attached :cover

  validates :title, presence: true
  validates :video_id, uniqueness: true, allow_nil: true

  before_validation :number_rows

  scope :search, ->(q) {
    next all if q.blank?
    term = "%#{sanitize_sql_like(q)}%"
    left_joins(:ingredients)
      .where("recipes.title LIKE :t OR recipes.creator LIKE :t OR ingredients.item LIKE :t", t: term)
      .distinct
  }

  def estimated_quantities?
    ingredients.any?(&:estimated?)
  end

  private

  def number_rows
    [ ingredients, steps ].each do |rows|
      rows.reject(&:marked_for_destruction?).each_with_index { |row, i| row.position = i + 1 }
    end
  end
end
