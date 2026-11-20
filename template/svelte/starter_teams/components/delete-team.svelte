<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"

  import HeadingSmall from "@/components/heading-small.svelte"
  import { Button } from "@/components/ui/button"
  import * as Dialog from "@/components/ui/dialog"
  import { Field, FieldError, FieldLabel } from "@/components/ui/field"
  import { Input } from "@/components/ui/input"
  import { settingsTeams } from "@/routes"
  import type { Team } from "@/types"

  let { team }: { team: Team } = $props()

  let confirmation = $state("")
</script>

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
      <p class="text-sm">Please proceed with caution, this cannot be undone.</p>
    </div>
    <Dialog.Root onOpenChange={() => (confirmation = "")}>
      <Dialog.Trigger>
        {#snippet child({ props })}
          <Button {...props} variant="destructive">Delete team</Button>
        {/snippet}
      </Dialog.Trigger>
      <Dialog.Content>
        <Form action={settingsTeams.destroy(team.slug)} class="space-y-6">
          {#snippet children({ errors, processing }: FormComponentSlotProps)}
            <Dialog.Header class="space-y-3">
              <Dialog.Title>Are you sure?</Dialog.Title>
              <Dialog.Description>
                This action cannot be undone. This will permanently delete the
                team <strong>{team.name}</strong>.
              </Dialog.Description>
            </Dialog.Header>

            <Field>
              <FieldLabel for="team_name_confirmation">
                Type the team name to confirm
              </FieldLabel>
              <Input
                id="team_name_confirmation"
                name="name"
                bind:value={confirmation}
                placeholder={team.name}
                autocomplete="off"
              />
              <FieldError
                errors={errors.name?.map((message) => ({ message }))}
              />
            </Field>

            <Dialog.Footer class="gap-2">
              <Dialog.Close>
                {#snippet child({ props })}
                  <Button {...props} variant="secondary">Cancel</Button>
                {/snippet}
              </Dialog.Close>

              <Button
                type="submit"
                variant="destructive"
                disabled={confirmation !== team.name || processing}
              >
                Delete team
              </Button>
            </Dialog.Footer>
          {/snippet}
        </Form>
      </Dialog.Content>
    </Dialog.Root>
  </div>
</div>
