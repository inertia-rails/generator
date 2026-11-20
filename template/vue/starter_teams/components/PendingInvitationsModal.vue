<script setup lang="ts">
import { router } from "@inertiajs/vue3"
import { ref } from "vue"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { invitations as invitationRoutes } from "@/routes"
import type { PendingInvitation } from "@/types"

interface Props {
  invitations: PendingInvitation[]
}

const props = defineProps<Props>()

const open = ref(true)
const processingCode = ref<string | null>(null)

const acceptInvitation = (invitation: PendingInvitation) => {
  router.visit(invitationRoutes.accept(invitation.code), {
    onStart: () => (processingCode.value = invitation.code),
    onFinish: () => (processingCode.value = null),
  })
}

const declineInvitation = (invitation: PendingInvitation) => {
  router.visit(invitationRoutes.destroy(invitation.code), {
    onStart: () => (processingCode.value = invitation.code),
    onFinish: () => (processingCode.value = null),
    onSuccess: () => {
      if (props.invitations.length === 1) {
        open.value = false
      }
    },
  })
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Pending team invitations</DialogTitle>
        <DialogDescription>
          Accept or decline the teams you have been invited to join.
        </DialogDescription>
      </DialogHeader>

      <div class="grid gap-4">
        <div
          v-for="invitation in props.invitations"
          :key="invitation.code"
          class="rounded-lg border p-4"
        >
          <div class="space-y-1">
            <p class="font-medium">{{ invitation.team_name }}</p>
            <p class="text-muted-foreground text-sm">
              {{ invitation.invited_by }} invited you to join this team.
            </p>
          </div>

          <div class="mt-4 flex justify-end gap-2">
            <Button
              variant="secondary"
              :disabled="processingCode === invitation.code"
              @click="declineInvitation(invitation)"
            >
              Decline
            </Button>

            <Button
              :disabled="processingCode === invitation.code"
              @click="acceptInvitation(invitation)"
            >
              Accept
            </Button>
          </div>
        </div>
      </div>
    </DialogContent>
  </Dialog>
</template>
