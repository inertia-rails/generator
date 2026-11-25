<script lang="ts">
  import { Info } from "@lucide/svelte"

  import { Alert, AlertDescription } from "@/components/ui/alert"
  import type { TeamInvitationContext } from "@/types"

  let {
    invitation,
    action,
  }: {
    invitation: TeamInvitationContext
    action: "Log in" | "Register"
  } = $props()
</script>

<Alert
  class="border-blue-200 bg-blue-50 text-blue-900 dark:border-blue-900/50 dark:bg-blue-950/50 dark:text-blue-100 [&>svg]:text-blue-600 dark:[&>svg]:text-blue-400"
>
  <Info class="size-4" />
  <AlertDescription class="text-blue-900 dark:text-blue-100">
    {action} to join the "{invitation.team_name}" team.
    {#if action === "Register"}
      Verify your email after signing up, then open your dashboard to accept.
    {/if}
  </AlertDescription>
</Alert>
