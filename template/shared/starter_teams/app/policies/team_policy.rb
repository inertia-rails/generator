# frozen_string_literal: true

# What each role can do:
#   owner  — everything
#   admin  — rename the team, invite people, cancel invitations
#   member — view the team, leave it (unless it is someone's personal team)
class TeamPolicy < ApplicationPolicy
  def show?
    membership.present?
  end

  def update?
    owner? || admin?
  end

  def destroy?
    owner? && !record.personal?
  end

  def leave?
    !record.personal? && membership.present? && !owner?
  end

  def invite?
    owner? || admin?
  end

  def update_member?
    owner?
  end

  def remove_member?
    owner?
  end

  private

  def membership
    @membership ||= record.memberships.find_by(user: user)
  end

  def owner?
    membership&.owner?
  end

  def admin?
    membership&.admin?
  end
end
