# frozen_string_literal: true

module HasTeams
  extend ActiveSupport::Concern

  included do
    # Teams nobody else belongs to go away with the account (see #shared_owned_teams
    # for the rest). Declared before the memberships association, so it runs
    # while they still exist.
    before_destroy { owned_teams.each(&:destroy!) }

    has_many :memberships, dependent: :destroy
    has_many :teams, through: :memberships
    has_many :owned_teams, -> { merge(Membership.owner) }, through: :memberships, source: :team
    has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id, dependent: :destroy

    belongs_to :current_team, class_name: "Team", optional: true

    after_create :create_personal_team
  end

  # The team the user worked in last. Falls back to the personal team,
  # e.g. after the last used team was deleted.
  def current_team
    super || personal_team
  end

  def personal_team
    owned_teams.find_by(personal: true)
  end

  # Owned teams that other people belong to. They block deleting the account:
  # the owner has to delete them or remove their members first.
  def shared_owned_teams
    owned_teams.where(id: Membership.where.not(user_id: id).select(:team_id))
  end

  def create_team(name:, personal: false)
    transaction do
      team = Team.new(name: name, personal: personal)
      team.memberships.build(user: self, role: :owner)
      update!(current_team: team) if team.save
      team
    end
  end

  # Invitations are matched by email, so the address has to be verified first.
  def pending_invitations
    verified? ? Invitation.pending.where(email: email) : Invitation.none
  end

  # Teams with the user's role in each one
  def teams_with_roles
    teams.select("teams.*", "memberships.role").order(:name)
  end

  private

  def create_personal_team
    create_team(name: "#{name}'s Team", personal: true)
  end
end
