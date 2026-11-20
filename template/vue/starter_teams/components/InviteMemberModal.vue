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
} from "@/components/ui/dialog"
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { settingsTeamsInvitations } from "@/routes"
import type { MembershipRole, Team } from "@/types"

interface Props {
  team: Team
  availableRoles: MembershipRole[]
  open: boolean
}

const props = defineProps<Props>()
const emit = defineEmits<{
  "update:open": [value: boolean]
}>()

const inviteRole = ref<MembershipRole>("member")
const formKey = ref(0)

function handleOpenChange(value: boolean) {
  emit("update:open", value)

  if (!value) {
    inviteRole.value = "member"
    formKey.value++
  }
}
</script>

<template>
  <Dialog :open="props.open" @update:open="handleOpenChange">
    <DialogContent>
      <Form
        :key="formKey"
        :action="settingsTeamsInvitations.create(props.team.slug)"
        class="space-y-6"
        #default="{ errors, processing }"
        @success="handleOpenChange(false)"
      >
        <DialogHeader>
          <DialogTitle>Invite a team member</DialogTitle>
          <DialogDescription>
            Send an invitation to join this team.
          </DialogDescription>
        </DialogHeader>

        <div class="grid gap-4">
          <Field>
            <FieldLabel for="invitation_email">Email address</FieldLabel>
            <Input
              id="invitation_email"
              name="email"
              type="email"
              placeholder="colleague@example.com"
              required
            />
            <FieldError :errors="errors.email" />
          </Field>

          <Field>
            <FieldLabel for="invitation_role">Role</FieldLabel>
            <Select v-model="inviteRole" name="role">
              <SelectTrigger id="invitation_role" class="w-full capitalize">
                <SelectValue placeholder="Select a role" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem
                  v-for="role in props.availableRoles"
                  :key="role"
                  :value="role"
                  class="capitalize"
                >
                  {{ role }}
                </SelectItem>
              </SelectContent>
            </Select>
            <FieldError :errors="errors.role" />
          </Field>
        </div>

        <DialogFooter class="gap-2">
          <DialogClose as-child>
            <Button variant="secondary"> Cancel </Button>
          </DialogClose>

          <Button type="submit" :disabled="processing">
            Send invitation
          </Button>
        </DialogFooter>
      </Form>
    </DialogContent>
  </Dialog>
</template>
