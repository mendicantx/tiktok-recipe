class Step < ApplicationRecord
  belongs_to :recipe

  validates :body, presence: true
end
