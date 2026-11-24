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
import { settingsTeams } from "@/routes"
import type { Team } from "@/types"

interface LeaveTeamModalProps {
  team: Team | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export default function LeaveTeamModal({
  team,
  open,
  onOpenChange,
}: LeaveTeamModalProps) {
  const [processing, setProcessing] = useState(false)

  const leaveTeam = () => {
    if (!team) {
      return
    }

    router.visit(settingsTeams.leave(team.to_param), {
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
      onSuccess: () => onOpenChange(false),
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Leave team</DialogTitle>
          <DialogDescription>
            Are you sure you want to leave <strong>{team?.name}</strong>?
          </DialogDescription>
        </DialogHeader>

        <DialogFooter className="gap-2">
          <DialogClose asChild>
            <Button variant="secondary">Cancel</Button>
          </DialogClose>

          <Button
            variant="destructive"
            disabled={processing}
            onClick={leaveTeam}
          >
            Leave team
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
