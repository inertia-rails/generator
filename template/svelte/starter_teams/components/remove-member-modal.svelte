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
  import { settingsTeamsMembers } from "@/routes"
  import type { Team, TeamMember } from "@/types"

  let {
    team,
    member,
    open = $bindable(),
  }: {
    team: Team
    member: TeamMember | null
    open: boolean
  } = $props()

  let processing = $state(false)

  const removeMember = () => {
    if (!member) {
      return
    }

    router.visit(settingsTeamsMembers.destroy({ teamId: team.to_param, id: member.id }), {
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
      <DialogTitle>Remove team member</DialogTitle>
      <DialogDescription>
        Are you sure you want to remove <strong>{member?.name}</strong> from
        this team?
      </DialogDescription>
    </div>

    <DialogFooter class="gap-2">
      <DialogClose>
        {#snippet child({ props })}
          <Button {...props} variant="secondary">Cancel</Button>
        {/snippet}
      </DialogClose>

      <Button variant="destructive" disabled={processing} onclick={removeMember}>
        Remove member
      </Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
