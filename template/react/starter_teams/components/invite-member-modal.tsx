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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { settingsTeamsInvitations } from "@/routes"
import type { MembershipRole, Team } from "@/types"

interface InviteMemberModalProps {
  team: Team
  availableRoles: MembershipRole[]
  open: boolean
  onOpenChange: (open: boolean) => void
}

export default function InviteMemberModal({
  team,
  availableRoles,
  open,
  onOpenChange,
}: InviteMemberModalProps) {
  const [inviteRole, setInviteRole] = useState<MembershipRole>("member")

  const handleOpenChange = (nextOpen: boolean) => {
    onOpenChange(nextOpen)

    if (!nextOpen) {
      setInviteRole("member")
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent>
        <Form
          key={String(open)}
          action={settingsTeamsInvitations.create(team.slug)}
          className="space-y-6"
          onSuccess={() => onOpenChange(false)}
        >
          {({ errors, processing }) => (
            <>
              <DialogHeader>
                <DialogTitle>Invite a team member</DialogTitle>
                <DialogDescription>
                  Send an invitation to join this team.
                </DialogDescription>
              </DialogHeader>

              <div className="grid gap-4">
                <Field>
                  <FieldLabel htmlFor="invitation_email">
                    Email address
                  </FieldLabel>
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
                  <FieldLabel htmlFor="invitation_role">Role</FieldLabel>
                  <Select
                    name="role"
                    value={inviteRole}
                    onValueChange={(value) => setInviteRole(value as MembershipRole)}
                  >
                    <SelectTrigger
                      id="invitation_role"
                      className="w-full capitalize"
                    >
                      <SelectValue placeholder="Select a role" />
                    </SelectTrigger>
                    <SelectContent>
                      {availableRoles.map((role) => (
                        <SelectItem
                          key={role}
                          value={role}
                          className="capitalize"
                        >
                          {role}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  <FieldError
                    errors={errors.role?.map((message) => ({ message }))}
                  />
                </Field>
              </div>

              <DialogFooter className="gap-2">
                <DialogClose asChild>
                  <Button variant="secondary">Cancel</Button>
                </DialogClose>

                <Button type="submit" disabled={processing}>
                  Send invitation
                </Button>
              </DialogFooter>
            </>
          )}
        </Form>
      </DialogContent>
    </Dialog>
  )
}
