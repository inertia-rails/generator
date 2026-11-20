import type { LucideIcon } from "lucide-react"

export interface Auth {
  user: User
  session: Pick<Session, "id">
}

export interface BreadcrumbItem {
  title: string
  href: string
}

export interface NavItem {
  title: string
  href: string
  icon?: LucideIcon | null
  isActive?: boolean
}

export interface FlashData {
  alert?: string
  notice?: string
}

export interface SharedProps {
  auth: Auth
<% if use_teams %>
  current_team: Team
  teams: Team[]
<% end %>
}
<% if use_teams %>

export type MembershipRole = "owner" | "admin" | "member"

export interface Team {
  id: number
  name: string
  slug: string
  personal: boolean
  role?: MembershipRole
}

export interface TeamMember {
  id: number
  name: string
  email: string
  avatar?: string
  role: MembershipRole
}

export interface TeamInvitation {
  code: string
  email: string
  role: MembershipRole
  created_at: string
}

export interface TeamPermissions {
  update: boolean
  destroy: boolean
  invite: boolean
  update_member: boolean
  remove_member: boolean
}

export interface TeamInvitationContext {
  code: string
  team_name: string
}

export interface PendingInvitation {
  code: string
  team_name: string
  invited_by: string
}
<% end %>

export interface User {
  id: number
  name: string
  email: string
  avatar?: string
  verified: boolean
  created_at: string
  updated_at: string
  [key: string]: unknown // This allows for additional properties...
}

export interface Session {
  id: number
  user_agent: string
  ip_address: string
  created_at: string
}
