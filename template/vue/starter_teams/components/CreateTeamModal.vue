<script setup lang="ts">
import { Form } from "@inertiajs/vue3"
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
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { settingsTeams } from "@/routes"

const open = ref(false)
const formKey = ref(0)

function handleOpenChange(value: boolean) {
  open.value = value

  if (!value) {
    formKey.value++
  }
}
</script>

<template>
  <Dialog :open="open" @update:open="handleOpenChange">
    <DialogTrigger as-child>
      <slot />
    </DialogTrigger>
    <DialogContent>
      <Form
        :key="formKey"
        :action="settingsTeams.create()"
        class="space-y-6"
        #default="{ errors, processing }"
        @success="open = false"
      >
        <DialogHeader>
          <DialogTitle>Create a new team</DialogTitle>
          <DialogDescription>
            Create a new team to collaborate with others.
          </DialogDescription>
        </DialogHeader>

        <Field>
          <FieldLabel for="team_name">Team name</FieldLabel>
          <Input id="team_name" name="name" placeholder="My team" required />
          <FieldError :errors="errors.name" />
        </Field>

        <DialogFooter class="gap-2">
          <DialogClose as-child>
            <Button variant="secondary"> Cancel </Button>
          </DialogClose>

          <Button type="submit" :disabled="processing"> Create team </Button>
        </DialogFooter>
      </Form>
    </DialogContent>
  </Dialog>
</template>
