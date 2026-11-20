<script setup lang="ts">
<% if use_teams %>
import { Head, usePage } from "@inertiajs/vue3"
import { computed } from "vue"

import PendingInvitationsModal from "@/components/PendingInvitationsModal.vue"
import AppLayout from "@/layouts/AppLayout.vue"
import { teamDashboard } from "@/routes"
import { type BreadcrumbItem, type DashboardShow } from "@/types"

import PlaceholderPattern from "../../components/PlaceholderPattern.vue"

defineProps<DashboardShow>()

const page = usePage()

const breadcrumbs = computed<BreadcrumbItem[]>(() => [
  {
    title: "Dashboard",
    href: teamDashboard(page.props.current_team.slug).url,
  },
])
<% else %>
import { Head } from "@inertiajs/vue3"

import AppLayout from "@/layouts/AppLayout.vue"
import { dashboard } from "@/routes"
import { type BreadcrumbItem } from "@/types"

import PlaceholderPattern from "../../components/PlaceholderPattern.vue"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Dashboard",
    href: dashboard.index().url,
  },
]
<% end %>
</script>

<template>
  <Head :title="breadcrumbs[breadcrumbs.length - 1].title" />
<% if use_teams %>

  <PendingInvitationsModal
    v-if="pending_invitations.length > 0"
    :invitations="pending_invitations"
  />
<% end %>

  <AppLayout :breadcrumbs="breadcrumbs">
    <div
      class="flex h-full flex-1 flex-col gap-4 overflow-x-auto rounded-xl p-4"
    >
      <div class="grid auto-rows-min gap-4 md:grid-cols-3">
        <div
          class="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border"
        >
          <PlaceholderPattern />
        </div>
        <div
          class="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border"
        >
          <PlaceholderPattern />
        </div>
        <div
          class="border-sidebar-border/70 dark:border-sidebar-border relative aspect-video overflow-hidden rounded-xl border"
        >
          <PlaceholderPattern />
        </div>
      </div>
      <div
        class="border-sidebar-border/70 dark:border-sidebar-border relative min-h-[100vh] flex-1 rounded-xl border md:min-h-min"
      >
        <PlaceholderPattern />
      </div>
    </div>
  </AppLayout>
</template>
