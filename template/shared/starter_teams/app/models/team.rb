# frozen_string_literal: true

class Team < ApplicationRecord
  MAX_NAME_LENGTH = 255

  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :invitations, dependent: :destroy

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }

  to_param :name

  def owner
    memberships.owner.first&.user
  end
end
