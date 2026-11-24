import { router } from "@inertiajs/react"
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
import { settingsTeamsInvitations } from "@/routes"
import type { Team, TeamInvitation } from "@/types"

interface CancelInvitationModalProps {
  team: Team
  invitation: TeamInvitation | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export default function CancelInvitationModal({
  team,
  invitation,
  open,
  onOpenChange,
}: CancelInvitationModalProps) {
  const [processing, setProcessing] = useState(false)

  const cancelInvitation = () => {
    if (!invitation) {
      return
    }

    router.visit(
      settingsTeamsInvitations.destroy({
        teamId: team.to_param,
        code: invitation.code,
      }),
      {
        onStart: () => setProcessing(true),
        onFinish: () => setProcessing(false),
        onSuccess: () => onOpenChange(false),
      },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Cancel invitation</DialogTitle>
          <DialogDescription>
            Are you sure you want to cancel the invitation for{" "}
            <strong>{invitation?.email}</strong>?
          </DialogDescription>
        </DialogHeader>

        <DialogFooter className="gap-2">
          <DialogClose asChild>
            <Button variant="secondary">Keep invitation</Button>
          </DialogClose>

          <Button
            variant="destructive"
            disabled={processing}
            onClick={cancelInvitation}
          >
            Cancel invitation
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
