<script setup lang="ts">
import { router } from "@inertiajs/vue3"
import { ref } from "vue"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { settingsTeams } from "@/routes"
import type { Team } from "@/types"

interface Props {
  team: Team | null
  open: boolean
}

const props = defineProps<Props>()
const emit = defineEmits<{
  "update:open": [value: boolean]
}>()

const processing = ref(false)

const leaveTeam = () => {
  if (!props.team) {
    return
  }

  router.visit(settingsTeams.leave(props.team.slug), {
    onStart: () => (processing.value = true),
    onFinish: () => (processing.value = false),
    onSuccess: () => emit("update:open", false),
  })
}
</script>

<template>
  <Dialog :open="props.open" @update:open="emit('update:open', $event)">
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Leave team</DialogTitle>
        <DialogDescription>
          Are you sure you want to leave
          <strong>{{ props.team?.name }}</strong>?
        </DialogDescription>
      </DialogHeader>

      <DialogFooter class="gap-2">
        <DialogClose as-child>
          <Button variant="secondary"> Cancel </Button>
        </DialogClose>

        <Button variant="destructive" :disabled="processing" @click="leaveTeam">
          Leave team
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
