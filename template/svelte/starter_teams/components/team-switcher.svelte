<script lang="ts">
  import { Link, page } from "@inertiajs/svelte"
  import { Check, ChevronsUpDown, Plus, Users } from "@lucide/svelte"
  import { MediaQuery } from "svelte/reactivity"

  import CreateTeamModal from "@/components/create-team-modal.svelte"
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

  let { inHeader = false }: { inHeader?: boolean } = $props()

  const isMobile = new MediaQuery("(max-width: 767px)")

  const currentTeam = $derived(page.props.current_team)
  const teams = $derived(page.props.teams)

  let createTeamOpen = $state(false)

  // Opening a team's page switches to it. On a team page, stay on the same page.
  const teamUrl = (team: Team) => {
    const segment = `/${currentTeam.slug}/`

    return page.url.startsWith(segment)
      ? `/${team.slug}/${page.url.slice(segment.length)}`
      : teamDashboard(team.slug).url
  }
</script>

<DropdownMenu>
  <DropdownMenuTrigger>
    {#snippet child({ props })}
      <Button
        {...props}
        variant="ghost"
        class={inHeader
          ? "h-8 gap-1 px-2"
          : "data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground w-full justify-start px-2 has-[>svg]:px-2"}
      >
        <Users
          class={inHeader
            ? "hidden"
            : "hidden size-4 shrink-0 group-data-[collapsible=icon]:block"}
        />
        <div
          class={inHeader
            ? "grid flex-1 text-left text-sm leading-tight"
            : "grid flex-1 text-left text-sm leading-tight group-data-[collapsible=icon]:hidden"}
        >
          <span
            class={inHeader
              ? "max-w-[120px] truncate font-medium"
              : "truncate font-semibold"}
          >
            {currentTeam.name}
          </span>
        </div>
        <ChevronsUpDown
          class={inHeader
            ? "size-4 opacity-50"
            : "ml-auto size-4 group-data-[collapsible=icon]:hidden"}
        />
      </Button>
    {/snippet}
  </DropdownMenuTrigger>
  <DropdownMenuContent
    class={inHeader
      ? "w-56"
      : "w-(--bits-dropdown-menu-anchor-width) min-w-56 rounded-lg"}
    side={inHeader ? undefined : isMobile.current ? "bottom" : "right"}
    align={inHeader ? "end" : "start"}
    sideOffset={inHeader ? undefined : 4}
  >
    <DropdownMenuLabel class="text-muted-foreground text-xs">
      Teams
    </DropdownMenuLabel>

    {#each teams as team (team.id)}
      <DropdownMenuItem class="cursor-pointer gap-2 {inHeader ? '' : 'p-2'}">
        {#snippet child({ props })}
          <Link {...props} href={teamUrl(team)}>
            {team.name}
            {#if currentTeam.id === team.id}
              <Check class={inHeader ? "ml-auto size-4" : "ml-auto h-4 w-4"} />
            {/if}
          </Link>
        {/snippet}
      </DropdownMenuItem>
    {/each}

    <DropdownMenuSeparator />

    <DropdownMenuItem
      class="cursor-pointer gap-2 {inHeader ? '' : 'p-2'}"
      onSelect={() => (createTeamOpen = true)}
    >
      <Plus class={inHeader ? "size-4" : "h-4 w-4"} />
      <span class="text-muted-foreground">New team</span>
    </DropdownMenuItem>
  </DropdownMenuContent>
</DropdownMenu>

<CreateTeamModal bind:open={createTeamOpen} />
