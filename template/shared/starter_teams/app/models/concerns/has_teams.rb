# frozen_string_literal: true

module HasTeams
  extend ActiveSupport::Concern

  included do
    # Check ownership before the dependent memberships are destroyed.
    before_destroy :destroy_owned_teams

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

  def destroy_owned_teams
    # Lock the teams before checking membership so a new member cannot join
    # between the check and deletion.
    teams_to_destroy = owned_teams.order(:id).lock.to_a
    if Membership.where(team: teams_to_destroy).where.not(user_id: id).lock.exists?
      errors.add(:base, "Delete the teams you own or remove their members before deleting your account")
      throw :abort
    end

    teams_to_destroy.each(&:destroy!)
  end

  def create_personal_team
    suffix = "'s Team"
    team = create_team(name: name.first(Team::MAX_NAME_LENGTH - suffix.length) + suffix, personal: true)
    return if team.persisted?

    errors.add(:base, "Could not create personal team: #{team.errors.full_messages.to_sentence}")
    raise ActiveRecord::RecordInvalid.new(self)
  end
end
