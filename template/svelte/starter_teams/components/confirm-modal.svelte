<script lang="ts">
  import { router } from "@inertiajs/svelte"
  import type { Snippet } from "svelte"

  import { Button } from "@/components/ui/button"
  import * as Dialog from "@/components/ui/dialog"
  import type { Method, RouteDefinition } from "@/routes/runtime"

  // Asks before running a destructive action.
  interface Props {
    title: string
    confirmLabel: string
    action: RouteDefinition<Method>
    // The button that opens the modal
    trigger: Snippet<[Record<string, unknown>]>
    description: Snippet
  }

  let { title, confirmLabel, action, trigger, description }: Props = $props()

  let open = $state(false)
  let processing = $state(false)

  const confirm = () => {
    router.visit(action.url, {
      method: action.method,
      preserveScroll: true,
      onStart: () => (processing = true),
      onFinish: () => (processing = false),
      onSuccess: () => (open = false),
    })
  }
</script>

<Dialog.Root bind:open>
  <Dialog.Trigger>
    {#snippet child({ props })}
      {@render trigger(props)}
    {/snippet}
  </Dialog.Trigger>
  <Dialog.Content>
    <Dialog.Header class="space-y-3">
      <Dialog.Title>{title}</Dialog.Title>
      <Dialog.Description>
        {@render description()}
      </Dialog.Description>
    </Dialog.Header>

    <Dialog.Footer class="gap-2">
      <Dialog.Close>
        {#snippet child({ props })}
          <Button {...props} variant="secondary">Cancel</Button>
        {/snippet}
      </Dialog.Close>

      <Button variant="destructive" disabled={processing} onclick={confirm}>
        {confirmLabel}
      </Button>
    </Dialog.Footer>
  </Dialog.Content>
</Dialog.Root>
