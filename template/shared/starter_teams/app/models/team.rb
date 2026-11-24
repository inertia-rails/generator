# frozen_string_literal: true

class Team < ApplicationRecord
  MAX_NAME_LENGTH = 255

  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :invitations, dependent: :destroy

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validate :name_is_not_reserved, if: :name_changed?

  before_save :assign_slug, if: :name_changed?

  # Team pages live at /:team_slug/..., so a team cannot be named after
  # the first segment of any other route (e.g. "settings").
  def self.route_prefixes
    Rails.application.routes.routes.filter_map { |route| route.path.spec.to_s[%r{\A/([\w-]+)}, 1] }.uniq
  end

  def to_param
    slug
  end

  def owner
    memberships.owner.first&.user
  end

  private

  def name_is_not_reserved
    slug = name.to_s.parameterize

    errors.add(:name, "is reserved") if ReservedNames::ALL.include?(slug) || self.class.route_prefixes.include?(slug)
  end

  def assign_slug
    base = name.parameterize.presence || "team"
    candidate = base
    suffix = 1
    candidate = "#{base}-#{suffix += 1}" while Team.where.not(id: id).exists?(slug: candidate)
    self.slug = candidate
  end
end
