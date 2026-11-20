<script lang="ts">
  import { Link, page } from "@inertiajs/svelte"
  import { Eye, LogOut, Pencil, Plus } from "@lucide/svelte"

  import CreateTeamModal from "@/components/create-team-modal.svelte"
  import HeadingSmall from "@/components/heading-small.svelte"
  import LeaveTeamModal from "@/components/leave-team-modal.svelte"
  import { Badge } from "@/components/ui/badge"
  import { Button, buttonVariants } from "@/components/ui/button"
  import {
    Tooltip,
    TooltipContent,
    TooltipProvider,
    TooltipTrigger,
  } from "@/components/ui/tooltip"
  import AppLayout from "@/layouts/app-layout.svelte"
  import SettingsLayout from "@/layouts/settings/layout.svelte"
  import { settingsTeams } from "@/routes"
  import type { BreadcrumbItem, Team } from "@/types"

  const breadcrumbs: BreadcrumbItem[] = [
    {
      title: "Teams",
      href: settingsTeams.index().url,
    },
  ]

  const teams = $derived(page.props.teams)

  let leaveTeamDialogOpen = $state(false)
  let teamLeaving = $state<Team | null>(null)

  const openLeaveTeamDialog = (team: Team) => {
    teamLeaving = team
    leaveTeamDialogOpen = true
  }
</script>

<svelte:head>
  <title>{breadcrumbs[breadcrumbs.length - 1].title}</title>
</svelte:head>

<AppLayout {breadcrumbs}>
  <SettingsLayout>
    <div class="flex flex-col space-y-6">
      <div class="flex items-center justify-between">
        <HeadingSmall
          title="Teams"
          description="Manage your teams and team memberships"
        />

        <CreateTeamModal>
          {#snippet children(props)}
            <Button {...props}>
              <Plus class="h-4 w-4" /> New team
            </Button>
          {/snippet}
        </CreateTeamModal>
      </div>

      <div class="space-y-3">
        {#each teams as team (team.id)}
          <div
            class="flex items-center justify-between gap-4 rounded-lg border p-4"
          >
            <div class="flex items-center gap-4">
              <div>
                <div class="flex items-center gap-2">
                  <span class="font-medium">{team.name}</span>
                  {#if team.personal}
                    <Badge variant="secondary">Personal</Badge>
                  {/if}
                </div>
                <span class="text-muted-foreground text-sm capitalize">
                  {team.role}
                </span>
              </div>
            </div>

            <TooltipProvider delayDuration={0}>
              <div class="flex items-center gap-2">
                {#if !team.personal && team.role !== "owner"}
                  <Tooltip>
                    <TooltipTrigger>
                      {#snippet child({ props })}
                        <Button
                          {...props}
                          variant="ghost"
                          size="sm"
                          aria-label="Leave team"
                          onclick={() => openLeaveTeamDialog(team)}
                        >
                          <LogOut class="h-4 w-4" />
                        </Button>
                      {/snippet}
                    </TooltipTrigger>
                    <TooltipContent>
                      <p>Leave team</p>
                    </TooltipContent>
                  </Tooltip>
                {/if}

                {#if team.role === "member"}
                  <Tooltip>
                    <TooltipTrigger>
                      {#snippet child({ props })}
                        <Link
                          {...props}
                          href={settingsTeams.show(team.slug)}
                          class={buttonVariants({ variant: "ghost", size: "sm" })}
                          aria-label="View team"
                        >
                          <Eye class="h-4 w-4" />
                        </Link>
                      {/snippet}
                    </TooltipTrigger>
                    <TooltipContent>
                      <p>View team</p>
                    </TooltipContent>
                  </Tooltip>
                {:else}
                  <Tooltip>
                    <TooltipTrigger>
                      {#snippet child({ props })}
                        <Link
                          {...props}
                          href={settingsTeams.show(team.slug)}
                          class={buttonVariants({ variant: "ghost", size: "sm" })}
                          aria-label="Edit team"
                        >
                          <Pencil class="h-4 w-4" />
                        </Link>
                      {/snippet}
                    </TooltipTrigger>
                    <TooltipContent>
                      <p>Edit team</p>
                    </TooltipContent>
                  </Tooltip>
                {/if}
              </div>
            </TooltipProvider>
          </div>
        {/each}

        {#if teams.length === 0}
          <p class="text-muted-foreground py-8 text-center">
            You don't belong to any teams yet.
          </p>
        {/if}
      </div>
    </div>

    <LeaveTeamModal team={teamLeaving} bind:open={leaveTeamDialogOpen} />
  </SettingsLayout>
</AppLayout>
