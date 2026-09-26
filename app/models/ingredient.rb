class Ingredient < ApplicationRecord
  belongs_to :recipe

  validates :item, presence: true

  def amount
    [ quantity, unit ].compact_blank.join(" ")
  end
end
