<script setup lang="ts">
import { Head, Link, usePage } from "@inertiajs/vue3"
import { Eye, LogOut, Pencil, Plus } from "lucide-vue-next"
import { computed, ref } from "vue"

import CreateTeamModal from "@/components/CreateTeamModal.vue"
import HeadingSmall from "@/components/HeadingSmall.vue"
import LeaveTeamModal from "@/components/LeaveTeamModal.vue"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import AppLayout from "@/layouts/AppLayout.vue"
import SettingsLayout from "@/layouts/settings/Layout.vue"
import { settingsTeams } from "@/routes"
import type { BreadcrumbItem, Team } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Teams",
    href: settingsTeams.index().url,
  },
]

const page = usePage()
const teams = computed(() => page.props.teams)

const leaveTeamDialogOpen = ref(false)
const teamLeaving = ref<Team | null>(null)

const canLeaveTeam = (team: Team) => !team.personal && team.role !== "owner"

const openLeaveTeamDialog = (team: Team) => {
  teamLeaving.value = team
  leaveTeamDialogOpen.value = true
}
</script>

<template>
  <AppLayout :breadcrumbs="breadcrumbs">
    <Head :title="breadcrumbs[breadcrumbs.length - 1].title" />

    <SettingsLayout>
      <div class="flex flex-col space-y-6">
        <div class="flex items-center justify-between">
          <HeadingSmall
            title="Teams"
            description="Manage your teams and team memberships"
          />

          <CreateTeamModal>
            <Button><Plus /> New team</Button>
          </CreateTeamModal>
        </div>

        <div class="space-y-3">
          <div
            v-for="team in teams"
            :key="team.id"
            class="flex items-center justify-between gap-4 rounded-lg border p-4"
          >
            <div class="flex items-center gap-4">
              <div>
                <div class="flex items-center gap-2">
                  <span class="font-medium">{{ team.name }}</span>
                  <Badge v-if="team.personal" variant="secondary">
                    Personal
                  </Badge>
                </div>
                <span class="text-muted-foreground text-sm capitalize">
                  {{ team.role }}
                </span>
              </div>
            </div>

            <TooltipProvider>
              <div class="flex items-center gap-2">
                <Tooltip v-if="canLeaveTeam(team)">
                  <TooltipTrigger as-child>
                    <Button
                      variant="ghost"
                      size="sm"
                      aria-label="Leave team"
                      @click="openLeaveTeamDialog(team)"
                    >
                      <LogOut class="h-4 w-4" />
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>
                    <p>Leave team</p>
                  </TooltipContent>
                </Tooltip>

                <Tooltip v-if="team.role === 'member'">
                  <TooltipTrigger as-child>
                    <Button variant="ghost" size="sm" as-child>
                      <Link
                        :href="settingsTeams.show(team.slug)"
                        aria-label="View team"
                      >
                        <Eye class="h-4 w-4" />
                      </Link>
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>
                    <p>View team</p>
                  </TooltipContent>
                </Tooltip>

                <Tooltip v-else>
                  <TooltipTrigger as-child>
                    <Button variant="ghost" size="sm" as-child>
                      <Link
                        :href="settingsTeams.show(team.slug)"
                        aria-label="Edit team"
                      >
                        <Pencil class="h-4 w-4" />
                      </Link>
                    </Button>
                  </TooltipTrigger>
                  <TooltipContent>
                    <p>Edit team</p>
                  </TooltipContent>
                </Tooltip>
              </div>
            </TooltipProvider>
          </div>

          <p
            v-if="teams.length === 0"
            class="text-muted-foreground py-8 text-center"
          >
            You don't belong to any teams yet.
          </p>
        </div>
      </div>

      <LeaveTeamModal v-model:open="leaveTeamDialogOpen" :team="teamLeaving" />
    </SettingsLayout>
  </AppLayout>
</template>
