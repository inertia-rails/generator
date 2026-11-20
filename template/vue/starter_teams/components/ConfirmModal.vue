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
  DialogTrigger,
} from "@/components/ui/dialog"
import type { Method, RouteDefinition } from "@/routes/runtime"

// Asks before running a destructive action. Wrap it around the button that opens it.
const props = defineProps<{
  title: string
  confirmLabel: string
  action: RouteDefinition<Method>
}>()

const open = ref(false)
const processing = ref(false)

const confirm = () => {
  router.visit(props.action.url, {
    method: props.action.method,
    preserveScroll: true,
    onStart: () => (processing.value = true),
    onFinish: () => (processing.value = false),
    onSuccess: () => (open.value = false),
  })
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogTrigger as-child>
      <slot />
    </DialogTrigger>
    <DialogContent>
      <DialogHeader class="space-y-3">
        <DialogTitle>{{ title }}</DialogTitle>
        <DialogDescription>
          <slot name="description" />
        </DialogDescription>
      </DialogHeader>

      <DialogFooter class="gap-2">
        <DialogClose as-child>
          <Button variant="secondary">Cancel</Button>
        </DialogClose>

        <Button variant="destructive" :disabled="processing" @click="confirm">
          {{ confirmLabel }}
        </Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
