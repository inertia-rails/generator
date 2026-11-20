<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form, router } from "@inertiajs/svelte"
  import { ChevronDown, Mail, UserPlus, X } from "@lucide/svelte"

  import CancelInvitationModal from "@/components/cancel-invitation-modal.svelte"
  import DeleteTeamModal from "@/components/delete-team-modal.svelte"
  import HeadingSmall from "@/components/heading-small.svelte"
  import InviteMemberModal from "@/components/invite-member-modal.svelte"
  import RemoveMemberModal from "@/components/remove-member-modal.svelte"
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
  import AppLayout from "@/layouts/app-layout.svelte"
  import SettingsLayout from "@/layouts/settings/layout.svelte"
  import { settingsTeams, settingsTeamsMembers } from "@/routes"
  import { getInitials } from "@/runes/use-initials"
  import type {
    BreadcrumbItem,
    MembershipRole,
    Team,
    TeamInvitation,
    TeamMember,
    TeamPermissions,
  } from "@/types"

  let {
    team,
    members,
    invitations,
    permissions,
    assignable_roles,
  }: {
    team: Team
    members: TeamMember[]
    invitations: TeamInvitation[]
    permissions: TeamPermissions
    assignable_roles: MembershipRole[]
  } = $props()

  const breadcrumbs = $derived<BreadcrumbItem[]>([
    {
      title: "Teams",
      href: settingsTeams.index().url,
    },
    {
      title: team.name,
      href: settingsTeams.show(team.slug).url,
    },
  ])

  let inviteDialogOpen = $state(false)
  let removeMemberDialogOpen = $state(false)
  let memberToRemove = $state<TeamMember | null>(null)
  let cancelInvitationDialogOpen = $state(false)
  let invitationToCancel = $state<TeamInvitation | null>(null)
  let deleteDialogOpen = $state(false)

  const pageTitle = $derived(
    permissions.update ? `Edit ${team.name}` : `View ${team.name}`,
  )

  const updateMemberRole = (member: TeamMember, newRole: MembershipRole) => {
    router.visit(
      settingsTeamsMembers.update({ teamSlug: team.slug, id: member.id }),
      {
        data: { role: newRole },
        preserveScroll: true,
      },
    )
  }

  const confirmRemoveMember = (member: TeamMember) => {
    memberToRemove = member
    removeMemberDialogOpen = true
  }

  const confirmCancelInvitation = (invitation: TeamInvitation) => {
    invitationToCancel = invitation
    cancelInvitationDialogOpen = true
  }
</script>

<svelte:head>
  <title>{pageTitle}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <SettingsLayout>
    <div class="flex flex-col space-y-10">
      {#if permissions.update}
        <div class="space-y-6">
          <HeadingSmall
            title="Team settings"
            description="Update your team name and settings"
          />

          <Form action={settingsTeams.update(team.slug)} class="space-y-6">
            {#snippet children({ errors, processing }: FormComponentSlotProps)}
              <Field>
                <FieldLabel for="name">Team name</FieldLabel>
                <Input id="name" name="name" value={team.name} required />
                <FieldError
                  errors={errors.name?.map((message) => ({ message }))}
                />
              </Field>

              <div class="flex items-center gap-4">
                <Button type="submit" disabled={processing}>Save</Button>
              </div>
            {/snippet}
          </Form>
        </div>
      {:else}
        <div class="space-y-6">
          <HeadingSmall title={team.name} />
        </div>
      {/if}

      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <HeadingSmall
            title="Team members"
            description={permissions.invite
              ? "Manage who belongs to this team"
              : ""}
          />

          {#if permissions.invite}
            <Button onclick={() => (inviteDialogOpen = true)}>
              <UserPlus class="h-4 w-4" /> Invite member
            </Button>
          {/if}
        </div>

        <div class="space-y-3">
          {#each members as member (member.id)}
            <div class="flex items-center justify-between rounded-lg border p-4">
              <div class="flex items-center gap-4">
                <Avatar class="h-10 w-10">
                  {#if member.avatar}
                    <AvatarImage src={member.avatar} alt={member.name} />
                  {/if}
                  <AvatarFallback>{getInitials(member.name)}</AvatarFallback>
                </Avatar>
                <div>
                  <div class="font-medium">{member.name}</div>
                  <div class="text-muted-foreground text-sm">
                    {member.email}
                  </div>
                </div>
              </div>

              <div class="flex items-center gap-2">
                {#if member.role !== "owner" && permissions.update_member}
                  <DropdownMenu>
                    <DropdownMenuTrigger>
                      {#snippet child({ props })}
                        <Button
                          {...props}
                          variant="outline"
                          size="sm"
                          class="capitalize"
                        >
                          {member.role}
                          <ChevronDown class="ml-2 h-4 w-4 opacity-50" />
                        </Button>
                      {/snippet}
                    </DropdownMenuTrigger>
                    <DropdownMenuContent>
                      {#each assignable_roles as role (role)}
                        <DropdownMenuItem
                          class="capitalize"
                          onSelect={() => updateMemberRole(member, role)}
                        >
                          {role}
                        </DropdownMenuItem>
                      {/each}
                    </DropdownMenuContent>
                  </DropdownMenu>
                {:else}
                  <Badge variant="secondary" class="capitalize">
                    {member.role}
                  </Badge>
                {/if}

                {#if member.role !== "owner" && permissions.remove_member}
                  <TooltipProvider delayDuration={0}>
                    <Tooltip>
                      <TooltipTrigger>
                        {#snippet child({ props })}
                          <Button
                            {...props}
                            variant="ghost"
                            size="sm"
                            aria-label={`Remove ${member.name}`}
                            onclick={() => confirmRemoveMember(member)}
                          >
                            <X class="h-4 w-4" />
                          </Button>
                        {/snippet}
                      </TooltipTrigger>
                      <TooltipContent>
                        <p>Remove member</p>
                      </TooltipContent>
                    </Tooltip>
                  </TooltipProvider>
                {/if}
              </div>
            </div>
          {/each}
        </div>
      </div>

      {#if invitations.length > 0}
        <div class="space-y-6">
          <HeadingSmall
            title="Pending invitations"
            description="Invitations that haven't been accepted yet"
          />

          <div class="space-y-3">
            {#each invitations as invitation (invitation.code)}
              <div
                class="flex items-center justify-between rounded-lg border p-4"
              >
                <div class="flex items-center gap-4">
                  <div
                    class="bg-muted flex h-10 w-10 items-center justify-center rounded-full"
                  >
                    <Mail class="text-muted-foreground h-5 w-5" />
                  </div>
                  <div>
                    <div class="font-medium">{invitation.email}</div>
                    <div class="text-muted-foreground text-sm capitalize">
                      {invitation.role}
                    </div>
                  </div>
                </div>

                {#if permissions.invite}
                  <TooltipProvider delayDuration={0}>
                    <Tooltip>
                      <TooltipTrigger>
                        {#snippet child({ props })}
                          <Button
                            {...props}
                            variant="ghost"
                            size="sm"
                            aria-label={`Cancel invitation for ${invitation.email}`}
                            onclick={() => confirmCancelInvitation(invitation)}
                          >
                            <X class="h-4 w-4" />
                          </Button>
                        {/snippet}
                      </TooltipTrigger>
                      <TooltipContent>
                        <p>Cancel invitation</p>
                      </TooltipContent>
                    </Tooltip>
                  </TooltipProvider>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {/if}

      {#if permissions.destroy && !team.personal}
        <div class="space-y-6">
          <HeadingSmall
            title="Delete team"
            description="Permanently delete your team"
          />
          <div
            class="space-y-4 rounded-lg border border-red-100 bg-red-50 p-4 dark:border-red-200/10 dark:bg-red-700/10"
          >
            <div class="relative space-y-0.5 text-red-600 dark:text-red-100">
              <p class="font-medium">Warning</p>
              <p class="text-sm">
                Please proceed with caution, this cannot be undone.
              </p>
            </div>
            <Button
              variant="destructive"
              onclick={() => (deleteDialogOpen = true)}
            >
              Delete team
            </Button>
          </div>
        </div>
      {/if}
    </div>

    {#if permissions.invite}
      <InviteMemberModal
        {team}
        availableRoles={assignable_roles}
        bind:open={inviteDialogOpen}
      />
    {/if}

    <RemoveMemberModal
      {team}
      member={memberToRemove}
      bind:open={removeMemberDialogOpen}
    />

    <CancelInvitationModal
      {team}
      invitation={invitationToCancel}
      bind:open={cancelInvitationDialogOpen}
    />

    {#if permissions.destroy && !team.personal}
      <DeleteTeamModal {team} bind:open={deleteDialogOpen} />
    {/if}
  </SettingsLayout>
</AppLayout>
