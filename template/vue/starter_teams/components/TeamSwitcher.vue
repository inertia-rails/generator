<script setup lang="ts">
import { Link, usePage } from "@inertiajs/vue3"
import { useMediaQuery } from "@vueuse/core"
import { Check, ChevronsUpDown, Plus, Users } from "lucide-vue-next"
import { computed } from "vue"

import CreateTeamModal from "@/components/CreateTeamModal.vue"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { teamDashboard } from "@/routes"
import type { Team } from "@/types"

const props = withDefaults(
  defineProps<{
    inHeader?: boolean
  }>(),
  {
    inHeader: false,
  },
)

const page = usePage()
const isMobile = useMediaQuery("(max-width: 767px)")

const currentTeam = computed(() => page.props.current_team)
const teams = computed(() => page.props.teams)
const menuContentClass = computed(() =>
  props.inHeader
    ? "w-56"
    : "w-(--reka-dropdown-menu-trigger-width) min-w-56 rounded-lg",
)
const teamItemClass = computed(() =>
  props.inHeader ? "cursor-pointer gap-2" : "cursor-pointer gap-2 p-2",
)
const checkIconClass = computed(() =>
  props.inHeader ? "ml-auto size-4" : "ml-auto h-4 w-4",
)
const plusIconClass = computed(() => (props.inHeader ? "size-4" : "h-4 w-4"))

// Opening a team's page switches to it. On a team page, stay on the same page.
const teamUrl = (team: Team) => {
  const [, teamParam, ...path] = page.url.split("/")

  return teamParam?.split("-")[0] === String(currentTeam.value?.id)
    ? `/${team.to_param}/${path.join("/")}`
    : teamDashboard(team.to_param).url
}
</script>

<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <Button
        variant="ghost"
        :class="
          props.inHeader
            ? 'h-8 gap-1 px-2'
            : 'data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground w-full justify-start px-2 has-[>svg]:px-2'
        "
      >
        <Users
          :class="
            props.inHeader
              ? 'hidden'
              : 'hidden size-4 shrink-0 group-data-[collapsible=icon]:block'
          "
        />
        <div
          :class="
            props.inHeader
              ? 'grid flex-1 text-left text-sm leading-tight'
              : 'grid flex-1 text-left text-sm leading-tight group-data-[collapsible=icon]:hidden'
          "
        >
          <span
            :class="
              props.inHeader
                ? 'max-w-[120px] truncate font-medium'
                : 'truncate font-semibold'
            "
          >
            {{ currentTeam?.name ?? "Select team" }}
          </span>
        </div>
        <ChevronsUpDown
          :class="
            props.inHeader
              ? 'size-4 opacity-50'
              : 'ml-auto group-data-[collapsible=icon]:hidden'
          "
        />
      </Button>
    </DropdownMenuTrigger>

    <DropdownMenuContent
      :class="menuContentClass"
      :side="props.inHeader ? undefined : isMobile ? 'bottom' : 'right'"
      :align="props.inHeader ? 'end' : 'start'"
      :side-offset="props.inHeader ? undefined : 4"
    >
      <DropdownMenuLabel class="text-muted-foreground text-xs">
        Teams
      </DropdownMenuLabel>
      <DropdownMenuItem
        v-for="team in teams"
        :key="team.id"
        :class="teamItemClass"
        as-child
      >
        <Link :href="teamUrl(team)">
          {{ team.name }}
          <Check v-if="currentTeam?.id === team.id" :class="checkIconClass" />
        </Link>
      </DropdownMenuItem>
      <DropdownMenuSeparator />
      <CreateTeamModal>
        <DropdownMenuItem :class="teamItemClass" @select.prevent>
          <Plus :class="plusIconClass" />
          <span class="text-muted-foreground">New team</span>
        </DropdownMenuItem>
      </CreateTeamModal>
    </DropdownMenuContent>
  </DropdownMenu>
</template>
