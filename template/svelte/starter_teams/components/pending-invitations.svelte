<script lang="ts">
  import { Link } from "@inertiajs/svelte"

  import { buttonVariants } from "@/components/ui/button"
  import { invitations as invitationRoutes } from "@/routes"
  import type { PendingInvitation } from "@/types"

  // Invitations to join other teams, sent to the current user's email address
  let { invitations }: { invitations: PendingInvitation[] } = $props()
</script>

{#each invitations as invitation (invitation.code)}
  <div
    class="flex flex-wrap items-center justify-between gap-4 rounded-xl border p-4"
  >
    <div class="space-y-1">
      <p class="font-medium">{invitation.team_name}</p>
      <p class="text-muted-foreground text-sm">
        {invitation.invited_by} invited you to join this team.
      </p>
    </div>

    <div class="flex gap-2">
      <Link
        href={invitationRoutes.destroy(invitation.code)}
        as="button"
        class={buttonVariants({ variant: "secondary" })}
      >
        Decline
      </Link>

      <Link
        href={invitationRoutes.accept(invitation.code)}
        as="button"
        class={buttonVariants()}
      >
        Accept
      </Link>
    </div>
  </div>
{/each}
