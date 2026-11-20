<script lang="ts">
  import { router } from "@inertiajs/svelte"

  import { Button } from "@/components/ui/button"
  import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogTitle,
  } from "@/components/ui/dialog"
  import { invitations as invitationRoutes } from "@/routes"
  import type { PendingInvitation } from "@/types"

  let {
    invitations,
  }: {
    invitations: PendingInvitation[]
  } = $props()

  let open = $state(true)
  let processingCode = $state<string | null>(null)

  const acceptInvitation = (invitation: PendingInvitation) => {
    router.visit(invitationRoutes.accept(invitation.code), {
      onStart: () => (processingCode = invitation.code),
      onFinish: () => (processingCode = null),
    })
  }

  const declineInvitation = (invitation: PendingInvitation) => {
    router.visit(invitationRoutes.destroy(invitation.code), {
      onStart: () => (processingCode = invitation.code),
      onFinish: () => (processingCode = null),
      onSuccess: () => {
        if (invitations.length === 1) {
          open = false
        }
      },
    })
  }
</script>

<Dialog bind:open>
  <DialogContent>
    <div class="space-y-3">
      <DialogTitle>Pending team invitations</DialogTitle>
      <DialogDescription>
        Accept or decline the teams you have been invited to join.
      </DialogDescription>
    </div>

    <div class="grid gap-4">
      {#each invitations as invitation (invitation.code)}
        <div class="rounded-lg border p-4">
          <div class="space-y-1">
            <p class="font-medium">{invitation.team_name}</p>
            <p class="text-muted-foreground text-sm">
              {invitation.invited_by} invited you to join this team.
            </p>
          </div>

          <div class="mt-4 flex justify-end gap-2">
            <Button
              variant="secondary"
              disabled={processingCode === invitation.code}
              onclick={() => declineInvitation(invitation)}
            >
              Decline
            </Button>

            <Button
              disabled={processingCode === invitation.code}
              onclick={() => acceptInvitation(invitation)}
            >
              Accept
            </Button>
          </div>
        </div>
      {/each}
    </div>
  </DialogContent>
</Dialog>
