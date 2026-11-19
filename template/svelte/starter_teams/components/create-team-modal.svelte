<script lang="ts">
  import type { FormComponentSlotProps } from "@inertiajs/core"
  import { Form } from "@inertiajs/svelte"
  import type { Snippet } from "svelte"

  import { Button } from "@/components/ui/button"
  import {
    Dialog,
    DialogClose,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogTitle,
    DialogTrigger,
  } from "@/components/ui/dialog"
  import { Field, FieldError, FieldLabel } from "@/components/ui/field"
  import { Input } from "@/components/ui/input"
  import { settingsTeams } from "@/routes"

  let {
    open = $bindable(false),
    children: trigger,
  }: {
    open?: boolean
    // The button that opens the modal. Leave it out to control `open` yourself.
    children?: Snippet<[Record<string, unknown>]>
  } = $props()

  let formKey = $state(0)

  function handleOpenChange(value: boolean) {
    open = value

    if (!value) {
      formKey++
    }
  }
</script>

<Dialog {open} onOpenChange={handleOpenChange}>
  {#if trigger}
    <DialogTrigger>
      {#snippet child({ props })}
        {@render trigger(props)}
      {/snippet}
    </DialogTrigger>
  {/if}
  <DialogContent>
    {#key formKey}
      <Form
        action={settingsTeams.create()}
        class="space-y-6"
        onSuccess={() => (open = false)}
      >
        {#snippet children({ errors, processing }: FormComponentSlotProps)}
          <div class="space-y-3">
            <DialogTitle>Create a new team</DialogTitle>
            <DialogDescription>
              Create a new team to collaborate with others.
            </DialogDescription>
          </div>

          <Field>
            <FieldLabel for="team_name">Team name</FieldLabel>
            <Input id="team_name" name="name" placeholder="My team" required />
            <FieldError
              errors={errors.name?.map((message) => ({ message }))}
            />
          </Field>

          <DialogFooter class="gap-2">
            <DialogClose>
              {#snippet child({ props })}
                <Button {...props} variant="secondary">Cancel</Button>
              {/snippet}
            </DialogClose>

            <Button type="submit" disabled={processing}>Create team</Button>
          </DialogFooter>
        {/snippet}
      </Form>
    {/key}
  </DialogContent>
</Dialog>
