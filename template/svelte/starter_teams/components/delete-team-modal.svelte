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
  import { settingsTeams } from "@/routes"
  import type { Team } from "@/types"

  let {
    team,
    open = $bindable(),
  }: {
    team: Team
    open: boolean
  } = $props()

  let confirmationName = $state("")
  let formKey = $state(0)

  const canDeleteTeam = $derived(confirmationName === team.name)

  function handleOpenChange(value: boolean) {
    open = value

    if (!value) {
      confirmationName = ""
      formKey++
    }
  }
</script>

<Dialog {open} onOpenChange={handleOpenChange}>
  <DialogContent>
    {#key formKey}
      <Form
        action={settingsTeams.destroy(team.slug)}
        class="space-y-6"
        onSuccess={() => handleOpenChange(false)}
      >
        {#snippet children({ errors, processing }: FormComponentSlotProps)}
          <div class="space-y-3">
            <DialogTitle>Are you sure?</DialogTitle>
            <DialogDescription>
              This action cannot be undone. This will permanently delete the
              team <strong>"{team.name}"</strong>.
            </DialogDescription>
          </div>

          <div class="space-y-4 py-4">
            <Field>
              <FieldLabel for="confirmation-name">
                Type <strong>"{team.name}"</strong> to confirm
              </FieldLabel>
              <Input
                id="confirmation-name"
                name="name"
                bind:value={confirmationName}
                placeholder="Enter team name"
                autocomplete="off"
              />
              <FieldError
                errors={errors.name?.map((message) => ({ message }))}
              />
            </Field>
          </div>

          <DialogFooter class="gap-2">
            <DialogClose>
              {#snippet child({ props })}
                <Button {...props} variant="secondary">Cancel</Button>
              {/snippet}
            </DialogClose>

            <Button
              variant="destructive"
              type="submit"
              disabled={!canDeleteTeam || processing}
            >
              Delete team
            </Button>
          </DialogFooter>
        {/snippet}
      </Form>
    {/key}
  </DialogContent>
</Dialog>
