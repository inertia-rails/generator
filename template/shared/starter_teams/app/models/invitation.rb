# frozen_string_literal: true

class Invitation < ApplicationRecord
  belongs_to :team
  belongs_to :invited_by, class_name: "User"

  has_secure_token :code

  enum :role, Membership.roles, validate: true

  normalizes :email, with: -> { _1.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_is_not_a_member, :email_is_not_invited, on: :create

  before_create { self.expires_at ||= 3.days.from_now }

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  # Deleted daily in production, see config/recurring.yml
  scope :expired, -> { where(expires_at: ...Time.current) }

  def to_param
    code
  end

  def pending?
    accepted_at.nil? && expires_at.future?
  end

  def accept!(user)
    transaction do
      team.memberships.create_with(role: role).find_or_create_by!(user: user)
      update!(accepted_at: Time.current)
      user.update!(current_team: team)
    end
  end

  private

  def email_is_not_a_member
    return unless team&.members&.exists?(email: email)

    errors.add(:email, "is already a member of the team")
  end

  def email_is_not_invited
    return unless team&.invitations&.pending&.exists?(email: email)

    errors.add(:email, "has already been invited")
  end
end
