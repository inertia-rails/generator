import { Form } from "@inertiajs/react"
import type { PropsWithChildren } from "react"
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
  DialogTrigger,
} from "@/components/ui/dialog"
import { Field, FieldError, FieldLabel } from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { settingsTeams } from "@/routes"

export default function CreateTeamModal({ children }: PropsWithChildren) {
  const [open, setOpen] = useState(false)

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent>
        <Form
          key={String(open)}
          action={settingsTeams.create()}
          className="space-y-6"
          onSuccess={() => setOpen(false)}
        >
          {({ errors, processing }) => (
            <>
              <DialogHeader>
                <DialogTitle>Create a new team</DialogTitle>
                <DialogDescription>
                  Create a new team to collaborate with others.
                </DialogDescription>
              </DialogHeader>

              <Field>
                <FieldLabel htmlFor="team_name">Team name</FieldLabel>
                <Input
                  id="team_name"
                  name="name"
                  placeholder="My team"
                  required
                />
                <FieldError
                  errors={errors.name?.map((message) => ({ message }))}
                />
              </Field>

              <DialogFooter className="gap-2">
                <DialogClose asChild>
                  <Button variant="secondary">Cancel</Button>
                </DialogClose>

                <Button type="submit" disabled={processing}>
                  Create team
                </Button>
              </DialogFooter>
            </>
          )}
        </Form>
      </DialogContent>
    </Dialog>
  )
}
