<script lang="ts">
  import { router } from "@inertiajs/svelte"

  import { Button } from "@/components/ui/button"
  import {
    Dialog,
    DialogClose,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogTitle,
  } from "@/components/ui/dialog"
  import { settingsTeams } from "@/routes"
  import type { Team } from "@/types"

  let {
    team,
    open = $bindable(),
  }: {
    team: Team | null
    open: boolean
  } = $props()

  let processing = $state(false)

  const leaveTeam = () => {
    if (!team) {
      return
    }

    router.visit(settingsTeams.leave(team.to_param), {
      onStart: () => (processing = true),
      onFinish: () => (processing = false),
      onSuccess: () => {
        open = false
      },
    })
  }
</script>

<Dialog bind:open>
  <DialogContent>
    <div class="space-y-3">
      <DialogTitle>Leave team</DialogTitle>
      <DialogDescription>
        Are you sure you want to leave <strong>{team?.name}</strong>?
      </DialogDescription>
    </div>

    <DialogFooter class="gap-2">
      <DialogClose>
        {#snippet child({ props })}
          <Button {...props} variant="secondary">Cancel</Button>
        {/snippet}
      </DialogClose>

      <Button variant="destructive" disabled={processing} onclick={leaveTeam}>
        Leave team
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
