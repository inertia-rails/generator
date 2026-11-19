<script setup lang="ts">
import { Link } from "@inertiajs/vue3"

import { Button } from "@/components/ui/button"
import { invitations as invitationRoutes } from "@/routes"
import type { PendingInvitation } from "@/types"

// Invitations to join other teams, sent to the current user's email address
defineProps<{ invitations: PendingInvitation[] }>()
</script>

<template>
  <div
    v-for="invitation in invitations"
    :key="invitation.code"
    class="flex flex-wrap items-center justify-between gap-4 rounded-xl border p-4"
  >
    <div class="space-y-1">
      <p class="font-medium">{{ invitation.team_name }}</p>
      <p class="text-muted-foreground text-sm">
        {{ invitation.invited_by }} invited you to join this team.
      </p>
    </div>

    <div class="flex gap-2">
      <Button variant="secondary" as-child>
        <Link :href="invitationRoutes.destroy(invitation.code)" as="button">
          Decline
        </Link>
      </Button>

      <Button as-child>
        <Link :href="invitationRoutes.accept(invitation.code)" as="button">
          Accept
        </Link>
      </Button>
    </div>
  </div>
</template>
