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
  import { settingsTeamsInvitations } from "@/routes"
  import type { Team, TeamInvitation } from "@/types"

  let {
    team,
    invitation,
    open = $bindable(),
  }: {
    team: Team
    invitation: TeamInvitation | null
    open: boolean
  } = $props()

  let processing = $state(false)

  const cancelInvitation = () => {
    if (!invitation) {
      return
    }

    router.visit(settingsTeamsInvitations.destroy({
        teamId: team.to_param,
        code: invitation.code,
      }), {
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
      <DialogTitle>Cancel invitation</DialogTitle>
      <DialogDescription>
        Are you sure you want to cancel the invitation for
        <strong>{invitation?.email}</strong>?
      </DialogDescription>
    </div>

    <DialogFooter class="gap-2">
      <DialogClose>
        {#snippet child({ props })}
          <Button {...props} variant="secondary">Keep invitation</Button>
        {/snippet}
      </DialogClose>

      <Button variant="destructive" disabled={processing} onclick={cancelInvitation}>
        Cancel invitation
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
