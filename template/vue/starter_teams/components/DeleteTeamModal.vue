<script setup lang="ts">
import { Form } from "@inertiajs/vue3"
import { computed, ref } from "vue"

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
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { settingsTeams } from "@/routes"
import type { Team } from "@/types"

interface Props {
  team: Team
  open: boolean
}

const props = defineProps<Props>()
const emit = defineEmits<{
  "update:open": [value: boolean]
}>()

const confirmationName = ref("")
const formKey = ref(0)

const canDeleteTeam = computed(() => {
  return confirmationName.value === props.team.name
})

const handleOpenChange = (nextOpen: boolean) => {
  emit("update:open", nextOpen)

  if (!nextOpen) {
    confirmationName.value = ""
    formKey.value++
  }
}
</script>

<template>
  <Dialog :open="props.open" @update:open="handleOpenChange">
    <DialogContent>
      <Form
        :key="formKey"
        :action="settingsTeams.destroy(props.team.to_param)"
        class="space-y-6"
        #default="{ errors, processing }"
        @success="handleOpenChange(false)"
      >
        <DialogHeader>
          <DialogTitle>Are you sure?</DialogTitle>
          <DialogDescription>
            This action cannot be undone. This will permanently delete the team
            <strong>"{{ props.team.name }}"</strong>.
          </DialogDescription>
        </DialogHeader>

        <div class="space-y-4 py-4">
          <Field>
            <FieldLabel for="confirmation-name">
              Type <strong>"{{ props.team.name }}"</strong> to confirm
            </FieldLabel>
            <Input
              id="confirmation-name"
              name="name"
              v-model="confirmationName"
              placeholder="Enter team name"
              autocomplete="off"
            />
            <FieldError :errors="errors.name" />
          </Field>
        </div>

        <DialogFooter class="gap-2">
          <DialogClose as-child>
            <Button variant="secondary"> Cancel </Button>
          </DialogClose>

          <Button
            variant="destructive"
            type="submit"
            :disabled="!canDeleteTeam || processing"
          >
            Delete team
          </Button>
        </DialogFooter>
      </Form>
    </DialogContent>
  </Dialog>
</template>
