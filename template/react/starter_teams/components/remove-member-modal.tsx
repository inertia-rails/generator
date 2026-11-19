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
import { settingsTeamsMembers } from "@/routes"
import type { Team, TeamMember } from "@/types"

interface RemoveMemberModalProps {
  team: Team
  member: TeamMember | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export default function RemoveMemberModal({
  team,
  member,
  open,
  onOpenChange,
}: RemoveMemberModalProps) {
  const [processing, setProcessing] = useState(false)

  const removeMember = () => {
    if (!member) {
      return
    }

    router.visit(
      settingsTeamsMembers.destroy({ teamSlug: team.slug, id: member.id }),
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
          <DialogTitle>Remove team member</DialogTitle>
          <DialogDescription>
            Are you sure you want to remove <strong>{member?.name}</strong> from
            this team?
          </DialogDescription>
        </DialogHeader>

        <DialogFooter className="gap-2">
          <DialogClose asChild>
            <Button variant="secondary">Cancel</Button>
          </DialogClose>

          <Button
            variant="destructive"
            disabled={processing}
            onClick={removeMember}
          >
            Remove member
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
