<script setup lang="ts">
import { Form } from "@inertiajs/vue3"
import { ref } from "vue"

import HeadingSmall from "@/components/HeadingSmall.vue"
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
import type { Team } from "@/types"

defineProps<{ team: Team }>()

const confirmation = ref("")
</script>

<template>
  <div class="space-y-6">
    <HeadingSmall
      title="Delete team"
      description="Permanently delete your team"
    />
    <div
      class="space-y-4 rounded-lg border border-red-100 bg-red-50 p-4 dark:border-red-200/10 dark:bg-red-700/10"
    >
      <div class="relative space-y-0.5 text-red-600 dark:text-red-100">
        <p class="font-medium">Warning</p>
        <p class="text-sm">
          Please proceed with caution, this cannot be undone.
        </p>
      </div>
      <Dialog @update:open="confirmation = ''">
        <DialogTrigger as-child>
          <Button variant="destructive">Delete team</Button>
        </DialogTrigger>
        <DialogContent>
          <Form
            :action="settingsTeams.destroy(team.slug)"
            class="space-y-6"
            #default="{ errors, processing }"
          >
            <DialogHeader class="space-y-3">
              <DialogTitle>Are you sure?</DialogTitle>
              <DialogDescription>
                This action cannot be undone. This will permanently delete the
                team <strong>{{ team.name }}</strong
                >.
              </DialogDescription>
            </DialogHeader>

            <Field>
              <FieldLabel for="team_name_confirmation">
                Type the team name to confirm
              </FieldLabel>
              <Input
                id="team_name_confirmation"
                name="name"
                v-model="confirmation"
                :placeholder="team.name"
                autocomplete="off"
              />
              <FieldError :errors="errors.name" />
            </Field>

            <DialogFooter class="gap-2">
              <DialogClose as-child>
                <Button variant="secondary">Cancel</Button>
              </DialogClose>

              <Button
                type="submit"
                variant="destructive"
                :disabled="confirmation !== team.name || processing"
              >
                Delete team
              </Button>
            </DialogFooter>
          </Form>
        </DialogContent>
      </Dialog>
    </div>
  </div>
</template>
