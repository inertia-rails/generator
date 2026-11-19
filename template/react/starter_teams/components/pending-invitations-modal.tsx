import { router } from "@inertiajs/react"
import { useState } from "react"

import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { invitations as invitationRoutes } from "@/routes"
import type { PendingInvitation } from "@/types"

interface PendingInvitationsModalProps {
  invitations: PendingInvitation[]
  open: boolean
  onOpenChange: (open: boolean) => void
}

export default function PendingInvitationsModal({
  invitations,
  open,
  onOpenChange,
}: PendingInvitationsModalProps) {
  const [processingCode, setProcessingCode] = useState<string | null>(null)

  const acceptInvitation = (invitation: PendingInvitation) => {
    router.visit(invitationRoutes.accept(invitation.code), {
      onStart: () => setProcessingCode(invitation.code),
      onFinish: () => setProcessingCode(null),
    })
  }

  const declineInvitation = (invitation: PendingInvitation) => {
    router.visit(invitationRoutes.destroy(invitation.code), {
      onStart: () => setProcessingCode(invitation.code),
      onFinish: () => setProcessingCode(null),
      onSuccess: () => {
        if (invitations.length === 1) {
          onOpenChange(false)
        }
      },
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Pending team invitations</DialogTitle>
          <DialogDescription>
            Accept or decline the teams you have been invited to join.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4">
          {invitations.map((invitation) => (
            <div key={invitation.code} className="rounded-lg border p-4">
              <div className="space-y-1">
                <p className="font-medium">{invitation.team_name}</p>
                <p className="text-muted-foreground text-sm">
                  {invitation.invited_by} invited you to join this team.
                </p>
              </div>

              <div className="mt-4 flex justify-end gap-2">
                <Button
                  variant="secondary"
                  disabled={processingCode === invitation.code}
                  onClick={() => declineInvitation(invitation)}
                >
                  Decline
                </Button>

                <Button
                  disabled={processingCode === invitation.code}
                  onClick={() => acceptInvitation(invitation)}
                >
                  Accept
                </Button>
              </div>
            </div>
          ))}
        </div>
      </DialogContent>
    </Dialog>
  )
}
