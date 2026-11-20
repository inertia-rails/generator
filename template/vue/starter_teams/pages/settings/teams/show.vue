<script setup lang="ts">
import { Form, Head, router } from "@inertiajs/vue3"
import { ChevronDown, Mail, UserPlus, X } from "lucide-vue-next"
import { computed, ref } from "vue"

import CancelInvitationModal from "@/components/CancelInvitationModal.vue"
import DeleteTeamModal from "@/components/DeleteTeamModal.vue"
import HeadingSmall from "@/components/HeadingSmall.vue"
import InviteMemberModal from "@/components/InviteMemberModal.vue"
import RemoveMemberModal from "@/components/RemoveMemberModal.vue"
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
import { getInitials } from "@/composables/useInitials"
import AppLayout from "@/layouts/AppLayout.vue"
import SettingsLayout from "@/layouts/settings/Layout.vue"
import { settingsTeams, settingsTeamsMembers } from "@/routes"
import type {
  BreadcrumbItem,
  MembershipRole,
  SettingsTeamsShow,
  TeamInvitation,
  TeamMember,
} from "@/types"

const props = defineProps<SettingsTeamsShow>()

const breadcrumbs = computed<BreadcrumbItem[]>(() => [
  {
    title: "Teams",
    href: settingsTeams.index().url,
  },
  {
    title: props.team.name,
    href: settingsTeams.show(props.team.slug).url,
  },
])

const inviteDialogOpen = ref(false)
const removeMemberDialogOpen = ref(false)
const memberToRemove = ref<TeamMember | null>(null)
const cancelInvitationDialogOpen = ref(false)
const invitationToCancel = ref<TeamInvitation | null>(null)
const deleteDialogOpen = ref(false)

const pageTitle = computed(() =>
  props.permissions.update
    ? `Edit ${props.team.name}`
    : `View ${props.team.name}`,
)

const updateMemberRole = (member: TeamMember, newRole: MembershipRole) => {
  router.visit(
    settingsTeamsMembers.update({ teamSlug: props.team.slug, id: member.id }),
    {
      data: { role: newRole },
      preserveScroll: true,
    },
  )
}

const confirmRemoveMember = (member: TeamMember) => {
  memberToRemove.value = member
  removeMemberDialogOpen.value = true
}

const confirmCancelInvitation = (invitation: TeamInvitation) => {
  invitationToCancel.value = invitation
  cancelInvitationDialogOpen.value = true
}
</script>

<template>
  <AppLayout :breadcrumbs="breadcrumbs">
    <Head :title="pageTitle" />

    <SettingsLayout>
      <div class="flex flex-col space-y-10">
        <!-- Team Name Section -->
        <div v-if="permissions.update" class="space-y-6">
          <HeadingSmall
            title="Team settings"
            description="Update your team name and settings"
          />

          <Form
            :action="settingsTeams.update(team.slug)"
            class="space-y-6"
            #default="{ errors, processing }"
          >
            <Field>
              <FieldLabel for="name">Team name</FieldLabel>
              <Input id="name" name="name" :defaultValue="team.name" required />
              <FieldError :errors="errors.name" />
            </Field>

            <div class="flex items-center gap-4">
              <Button type="submit" :disabled="processing"> Save </Button>
            </div>
          </Form>
        </div>

        <div v-else class="space-y-6">
          <HeadingSmall :title="team.name" />
        </div>

        <!-- Members Section -->
        <div class="space-y-6">
          <div class="flex items-center justify-between">
            <HeadingSmall
              title="Team members"
              :description="
                permissions.invite ? 'Manage who belongs to this team' : ''
              "
            />

            <Button v-if="permissions.invite" @click="inviteDialogOpen = true">
              <UserPlus /> Invite member
            </Button>
          </div>

          <div class="space-y-3">
            <div
              v-for="member in members"
              :key="member.id"
              class="flex items-center justify-between rounded-lg border p-4"
            >
              <div class="flex items-center gap-4">
                <Avatar class="h-10 w-10">
                  <AvatarImage
                    v-if="member.avatar"
                    :src="member.avatar"
                    :alt="member.name"
                  />
                  <AvatarFallback>{{
                    getInitials(member.name)
                  }}</AvatarFallback>
                </Avatar>
                <div>
                  <div class="font-medium">
                    {{ member.name }}
                  </div>
                  <div class="text-muted-foreground text-sm">
                    {{ member.email }}
                  </div>
                </div>
              </div>

              <div class="flex items-center gap-2">
                <DropdownMenu
                  v-if="member.role !== 'owner' && permissions.update_member"
                >
                  <DropdownMenuTrigger as-child>
                    <Button variant="outline" size="sm" class="capitalize">
                      {{ member.role }}
                      <ChevronDown class="ml-2 h-4 w-4 opacity-50" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent>
                    <DropdownMenuItem
                      v-for="role in assignable_roles"
                      :key="role"
                      class="capitalize"
                      @select="updateMemberRole(member, role)"
                    >
                      {{ role }}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
                <Badge v-else variant="secondary" class="capitalize">
                  {{ member.role }}
                </Badge>

                <TooltipProvider
                  v-if="member.role !== 'owner' && permissions.remove_member"
                >
                  <Tooltip>
                    <TooltipTrigger as-child>
                      <Button
                        variant="ghost"
                        size="sm"
                        :aria-label="`Remove ${member.name}`"
                        @click="confirmRemoveMember(member)"
                      >
                        <X class="h-4 w-4" />
                      </Button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p>Remove member</p>
                    </TooltipContent>
                  </Tooltip>
                </TooltipProvider>
              </div>
            </div>
          </div>
        </div>

        <!-- Pending Invitations Section -->
        <div v-if="invitations.length > 0" class="space-y-6">
          <HeadingSmall
            title="Pending invitations"
            description="Invitations that haven't been accepted yet"
          />

          <div class="space-y-3">
            <div
              v-for="invitation in invitations"
              :key="invitation.code"
              class="flex items-center justify-between rounded-lg border p-4"
            >
              <div class="flex items-center gap-4">
                <div
                  class="bg-muted flex h-10 w-10 items-center justify-center rounded-full"
                >
                  <Mail class="text-muted-foreground h-5 w-5" />
                </div>
                <div>
                  <div class="font-medium">
                    {{ invitation.email }}
                  </div>
                  <div class="text-muted-foreground text-sm capitalize">
                    {{ invitation.role }}
                  </div>
                </div>
              </div>

              <TooltipProvider v-if="permissions.invite">
                <Tooltip>
                  <TooltipTrigger as-child>
                    <Button
                      variant="ghost"
                      size="sm"
                      :aria-label="`Cancel invitation for ${invitation.email}`"
                      @click="confirmCancelInvitation(invitation)"
                    >
                      <X class="h-4 w-4" />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>
                    <p>Cancel invitation</p>
                  </TooltipContent>
                </Tooltip>
              </TooltipProvider>
            </div>
          </div>
        </div>

        <!-- Delete Team Section -->
        <div v-if="permissions.destroy && !team.personal" class="space-y-6">
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
            <Button variant="destructive" @click="deleteDialogOpen = true">
              Delete team
            </Button>
          </div>
        </div>
      </div>

      <InviteMemberModal
        v-if="permissions.invite"
        v-model:open="inviteDialogOpen"
        :team="team"
        :available-roles="assignable_roles"
      />

      <RemoveMemberModal
        v-model:open="removeMemberDialogOpen"
        :team="team"
        :member="memberToRemove"
      />

      <CancelInvitationModal
        v-model:open="cancelInvitationDialogOpen"
        :team="team"
        :invitation="invitationToCancel"
      />

      <DeleteTeamModal
        v-if="permissions.destroy && !team.personal"
        v-model:open="deleteDialogOpen"
        :team="team"
      />
    </SettingsLayout>
  </AppLayout>
</template>
