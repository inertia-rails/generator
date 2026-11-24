# frozen_string_literal: true

class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.string :name, null: false

      t.boolean :personal, null: false, default: false

      t.timestamps
    end

    create_table :memberships do |t|
      t.references :team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps

      t.index [ :team_id, :user_id ], unique: true
    end

    create_table :invitations do |t|
      t.references :team, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false, index: true
      t.string :role, null: false
      t.string :code, null: false, index: { unique: true }

      t.datetime :expires_at, null: false
      t.datetime :accepted_at

      t.timestamps
    end

    add_reference :users, :current_team, foreign_key: { to_table: :teams, on_delete: :nullify }
  end
end
