import { Form } from "@inertiajs/react"
import { useState } from "react"

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

interface DeleteTeamModalProps {
  team: Team
  open: boolean
  onOpenChange: (open: boolean) => void
}

export default function DeleteTeamModal({
  team,
  open,
  onOpenChange,
}: DeleteTeamModalProps) {
  const [confirmationName, setConfirmationName] = useState("")

  const canDeleteTeam = confirmationName === team.name

  const handleOpenChange = (nextOpen: boolean) => {
    onOpenChange(nextOpen)

    if (!nextOpen) {
      setConfirmationName("")
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent>
        <Form
          key={String(open)}
          action={settingsTeams.destroy(team.slug)}
          className="space-y-6"
          onSuccess={() => handleOpenChange(false)}
        >
          {({ errors, processing }) => (
            <>
              <DialogHeader>
                <DialogTitle>Are you sure?</DialogTitle>
                <DialogDescription>
                  This action cannot be undone. This will permanently delete the
                  team <strong>&quot;{team.name}&quot;</strong>.
                </DialogDescription>
              </DialogHeader>

              <div className="space-y-4 py-4">
                <Field>
                  <FieldLabel htmlFor="confirmation-name">
                    Type <strong>&quot;{team.name}&quot;</strong> to confirm
                  </FieldLabel>
                  <Input
                    id="confirmation-name"
                    name="name"
                    value={confirmationName}
                    onChange={(event) =>
                      setConfirmationName(event.target.value)
                    }
                    placeholder="Enter team name"
                    autoComplete="off"
                  />
                  <FieldError
                    errors={errors.name?.map((message) => ({ message }))}
                  />
                </Field>
              </div>

              <DialogFooter className="gap-2">
                <DialogClose asChild>
                  <Button variant="secondary">Cancel</Button>
                </DialogClose>

                <Button
                  variant="destructive"
                  type="submit"
                  disabled={!canDeleteTeam || processing}
                >
                  Delete team
                </Button>
              </DialogFooter>
            </>
          )}
        </Form>
      </DialogContent>
    </Dialog>
  )
}
