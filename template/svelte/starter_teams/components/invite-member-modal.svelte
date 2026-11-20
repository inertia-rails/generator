<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"

  import { Button } from "@/components/ui/button"
  import {
    Dialog,
    DialogClose,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogTitle,
  } from "@/components/ui/dialog"
  import { Field, FieldError, FieldLabel } from "@/components/ui/field"
  import { Input } from "@/components/ui/input"
  import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
  } from "@/components/ui/select"
  import { settingsTeamsInvitations } from "@/routes"
  import type { MembershipRole, Team } from "@/types"

  let {
    team,
    availableRoles,
    open = $bindable(),
  }: {
    team: Team
    availableRoles: MembershipRole[]
    open: boolean
  } = $props()

  let inviteRole = $state<string>("member")
  let formKey = $state(0)

  function handleOpenChange(value: boolean) {
    open = value

    if (!value) {
      inviteRole = "member"
      formKey++
    }
  }
</script>

<Dialog {open} onOpenChange={handleOpenChange}>
  <DialogContent>
    {#key formKey}
      <Form
        action={settingsTeamsInvitations.create(team.slug)}
        class="space-y-6"
        onSuccess={() => handleOpenChange(false)}
      >
        {#snippet children({ errors, processing }: FormComponentSlotProps)}
          <div class="space-y-3">
            <DialogTitle>Invite a team member</DialogTitle>
            <DialogDescription>
              Send an invitation to join this team.
            </DialogDescription>
          </div>

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
              <FieldError
                errors={errors.email?.map((message) => ({ message }))}
              />
            </Field>

            <Field>
              <FieldLabel for="invitation_role">Role</FieldLabel>
              <Select type="single" name="role" bind:value={inviteRole}>
                <SelectTrigger id="invitation_role" class="w-full capitalize">
                  {inviteRole}
                </SelectTrigger>
                <SelectContent>
                  {#each availableRoles as role (role)}
                    <SelectItem value={role} class="capitalize">
                      {role}
                    </SelectItem>
                  {/each}
                </SelectContent>
              </Select>
              <FieldError
                errors={errors.role?.map((message) => ({ message }))}
              />
            </Field>
          </div>

          <DialogFooter class="gap-2">
            <DialogClose>
              {#snippet child({ props })}
                <Button {...props} variant="secondary">Cancel</Button>
              {/snippet}
            </DialogClose>

            <Button type="submit" disabled={processing}>Send invitation</Button>
          </DialogFooter>
        {/snippet}
      </Form>
    {/key}
  </DialogContent>
</Dialog>
