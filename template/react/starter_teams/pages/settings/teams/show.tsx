import { Form, Head, router } from "@inertiajs/react"
import { ChevronDown, Mail, UserPlus, X } from "lucide-react"
import { useState } from "react"

import CancelInvitationModal from "@/components/cancel-invitation-modal"
import DeleteTeamModal from "@/components/delete-team-modal"
import HeadingSmall from "@/components/heading-small"
import InviteMemberModal from "@/components/invite-member-modal"
import RemoveMemberModal from "@/components/remove-member-modal"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import { useInitials } from "@/hooks/use-initials"
import AppLayout from "@/layouts/app-layout"
import SettingsLayout from "@/layouts/settings/layout"
import { settingsTeams, settingsTeamsMembers } from "@/routes"
import type {
  BreadcrumbItem,
  MembershipRole,
  SettingsTeamsShow,
  TeamInvitation,
  TeamMember,
} from "@/types"

export default function TeamEdit({
  team,
  members,
  invitations,
  permissions,
  assignable_roles,
}: SettingsTeamsShow) {
  const getInitials = useInitials()

  const [inviteDialogOpen, setInviteDialogOpen] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
  const [removeMemberDialogOpen, setRemoveMemberDialogOpen] = useState(false)
  const [memberToRemove, setMemberToRemove] = useState<TeamMember | null>(null)
  const [cancelInvitationDialogOpen, setCancelInvitationDialogOpen] =
    useState(false)
  const [invitationToCancel, setInvitationToCancel] =
    useState<TeamInvitation | null>(null)

  const pageTitle = permissions.update
    ? `Edit ${team.name}`
    : `View ${team.name}`

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Teams",
      href: settingsTeams.index().url,
    },
    {
      title: team.name,
      href: settingsTeams.show(team.to_param).url,
    },
  ]

  const updateMemberRole = (member: TeamMember, newRole: MembershipRole) => {
    router.visit(
      settingsTeamsMembers.update({ teamId: team.to_param, id: member.id }),
      {
        data: { role: newRole },
        preserveScroll: true,
      },
    )
  }

  const confirmRemoveMember = (member: TeamMember) => {
    setMemberToRemove(member)
    setRemoveMemberDialogOpen(true)
  }

  const confirmCancelInvitation = (invitation: TeamInvitation) => {
    setInvitationToCancel(invitation)
    setCancelInvitationDialogOpen(true)
  }

  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={pageTitle} />

      <SettingsLayout>
        <div className="flex flex-col space-y-10">
          <div className="space-y-6">
            {permissions.update ? (
              <>
                <HeadingSmall
                  title="Team settings"
                  description="Update your team name and settings"
                />

                <Form
                  action={settingsTeams.update(team.to_param)}
                  className="space-y-6"
                >
                  {({ errors, processing }) => (
                    <>
                      <Field>
                        <FieldLabel htmlFor="name">Team name</FieldLabel>
                        <Input
                          id="name"
                          name="name"
                          defaultValue={team.name}
                          required
                        />
                        <FieldError
                          errors={errors.name?.map((message) => ({ message }))}
                        />
                      </Field>

                      <div className="flex items-center gap-4">
                        <Button type="submit" disabled={processing}>
                          Save
                        </Button>
                      </div>
                    </>
                  )}
                </Form>
              </>
            ) : (
              <HeadingSmall title={team.name} />
            )}
          </div>

          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <HeadingSmall
                title="Team members"
                description={
                  permissions.invite ? "Manage who belongs to this team" : ""
                }
              />

              {permissions.invite ? (
                <Button onClick={() => setInviteDialogOpen(true)}>
                  <UserPlus /> Invite member
                </Button>
              ) : null}
            </div>

            <div className="space-y-3">
              {members.map((member) => (
                <div
                  key={member.id}
                  className="flex items-center justify-between rounded-lg border p-4"
                >
                  <div className="flex items-center gap-4">
                    <Avatar className="h-10 w-10">
                      {member.avatar ? (
                        <AvatarImage src={member.avatar} alt={member.name} />
                      ) : null}
                      <AvatarFallback>
                        {getInitials(member.name)}
                      </AvatarFallback>
                    </Avatar>
                    <div>
                      <div className="font-medium">{member.name}</div>
                      <div className="text-muted-foreground text-sm">
                        {member.email}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    {member.role !== "owner" && permissions.update_member ? (
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button
                            variant="outline"
                            size="sm"
                            className="capitalize"
                          >
                            {member.role}
                            <ChevronDown className="ml-2 h-4 w-4 opacity-50" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent>
                          {assignable_roles.map((role) => (
                            <DropdownMenuItem
                              key={role}
                              className="capitalize"
                              onSelect={() => updateMemberRole(member, role)}
                            >
                              {role}
                            </DropdownMenuItem>
                          ))}
                        </DropdownMenuContent>
                      </DropdownMenu>
                    ) : (
                      <Badge variant="secondary" className="capitalize">
                        {member.role}
                      </Badge>
                    )}

                    {member.role !== "owner" && permissions.remove_member ? (
                      <TooltipProvider>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button
                              variant="ghost"
                              size="sm"
                              aria-label={`Remove ${member.name}`}
                              onClick={() => confirmRemoveMember(member)}
                            >
                              <X className="h-4 w-4" />
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>
                            <p>Remove member</p>
                          </TooltipContent>
                        </Tooltip>
                      </TooltipProvider>
                    ) : null}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {invitations.length > 0 ? (
            <div className="space-y-6">
              <HeadingSmall
                title="Pending invitations"
                description="Invitations that haven't been accepted yet"
              />

              <div className="space-y-3">
                {invitations.map((invitation) => (
                  <div
                    key={invitation.code}
                    className="flex items-center justify-between rounded-lg border p-4"
                  >
                    <div className="flex items-center gap-4">
                      <div className="bg-muted flex h-10 w-10 items-center justify-center rounded-full">
                        <Mail className="text-muted-foreground h-5 w-5" />
                      </div>
                      <div>
                        <div className="font-medium">{invitation.email}</div>
                        <div className="text-muted-foreground text-sm capitalize">
                          {invitation.role}
                        </div>
                      </div>
                    </div>

                    {permissions.invite ? (
                      <TooltipProvider>
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button
                              variant="ghost"
                              size="sm"
                              aria-label={`Cancel invitation for ${invitation.email}`}
                              onClick={() =>
                                confirmCancelInvitation(invitation)
                              }
                            >
                              <X className="h-4 w-4" />
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>
                            <p>Cancel invitation</p>
                          </TooltipContent>
                        </Tooltip>
                      </TooltipProvider>
                    ) : null}
                  </div>
                ))}
              </div>
            </div>
          ) : null}

          {permissions.destroy && !team.personal ? (
            <div className="space-y-6">
              <HeadingSmall
                title="Delete team"
                description="Permanently delete your team"
              />
              <div className="space-y-4 rounded-lg border border-red-100 bg-red-50 p-4 dark:border-red-200/10 dark:bg-red-700/10">
                <div className="relative space-y-0.5 text-red-600 dark:text-red-100">
                  <p className="font-medium">Warning</p>
                  <p className="text-sm">
                    Please proceed with caution, this cannot be undone.
                  </p>
                </div>
                <Button
                  variant="destructive"
                  onClick={() => setDeleteDialogOpen(true)}
                >
                  Delete team
                </Button>
              </div>
            </div>
          ) : null}
        </div>

        {permissions.invite ? (
          <InviteMemberModal
            team={team}
            availableRoles={assignable_roles}
            open={inviteDialogOpen}
            onOpenChange={setInviteDialogOpen}
          />
        ) : null}

        <RemoveMemberModal
          team={team}
          member={memberToRemove}
          open={removeMemberDialogOpen}
          onOpenChange={setRemoveMemberDialogOpen}
        />

        <CancelInvitationModal
          team={team}
          invitation={invitationToCancel}
          open={cancelInvitationDialogOpen}
          onOpenChange={setCancelInvitationDialogOpen}
        />

        {permissions.destroy && !team.personal ? (
          <DeleteTeamModal
            team={team}
            open={deleteDialogOpen}
            onOpenChange={setDeleteDialogOpen}
          />
        ) : null}
      </SettingsLayout>
    </AppLayout>
  )
}
