class Profile < ApplicationRecord
  ADMIN = 1
  USER = 2
  AFFILIATE = 3

  has_many :users, dependent: :nullify
end
