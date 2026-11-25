<script lang="ts">
  // import { Head } from "@inertiajs/svelte"

<% if use_teams %>
  import { page } from "@inertiajs/svelte"

  import PendingInvitationsModal from "@/components/pending-invitations-modal.svelte"
  import PlaceholderPattern from "@/components/placeholder-pattern.svelte"
  import AppLayout from "@/layouts/app-layout.svelte"
  import { dashboardRoute } from "@/lib/dashboard-route"
  import { type BreadcrumbItem, type DashboardShow } from "@/types"

  let { pending_invitations }: DashboardShow = $props()

  const breadcrumbs = $derived<BreadcrumbItem[]>([
    {
      title: "Dashboard",
      href: dashboardRoute(page.props.current_team).url,
    },
  ])
<% else %>
  import PlaceholderPattern from "@/components/placeholder-pattern.svelte"
  import AppLayout from "@/layouts/app-layout.svelte"
  import { dashboard } from "@/routes"
  import { type BreadcrumbItem } from "@/types"

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Dashboard",
      href: dashboard.index().url,
    },
  ]
<% end %>
</script>

<svelte:head>
  <title>{breadcrumbs[breadcrumbs.length - 1].title}</title>
</svelte:head>

<% if use_teams %>
{#if pending_invitations.length > 0}
  <PendingInvitationsModal invitations={pending_invitations} />
{/if}

<% end %>
<AppLayout {breadcrumbs}>
  <div class="flex h-full flex-1 flex-col gap-4 overflow-x-auto rounded-xl p-4">
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
