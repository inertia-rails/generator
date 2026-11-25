import { Head, Link, usePage } from "@inertiajs/react"
import { Eye, LogOut, Pencil, Plus } from "lucide-react"
import { useState } from "react"

import CreateTeamModal from "@/components/create-team-modal"
import HeadingSmall from "@/components/heading-small"
import LeaveTeamModal from "@/components/leave-team-modal"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip"
import AppLayout from "@/layouts/app-layout"
import SettingsLayout from "@/layouts/settings/layout"
import { settingsTeams } from "@/routes"
import type { BreadcrumbItem, Team } from "@/types"

const breadcrumbs: BreadcrumbItem[] = [
  {
    title: "Teams",
    href: settingsTeams.index().url,
  },
]

export default function TeamsIndex() {
  const { teams } = usePage().props

  const [leaveTeamDialogOpen, setLeaveTeamDialogOpen] = useState(false)
  const [teamLeaving, setTeamLeaving] = useState<Team | null>(null)

  const openLeaveTeamDialog = (team: Team) => {
    setTeamLeaving(team)
    setLeaveTeamDialogOpen(true)
  }

  return (
    <AppLayout breadcrumbs={breadcrumbs}>
      <Head title={breadcrumbs[breadcrumbs.length - 1].title} />

      <SettingsLayout>
        <div className="flex flex-col space-y-6">
          <div className="flex items-center justify-between">
            <HeadingSmall
              title="Teams"
              description="Manage your teams and team memberships"
            />

            <CreateTeamModal>
              <Button>
                <Plus /> New team
              </Button>
            </CreateTeamModal>
          </div>

          <div className="space-y-3">
            {teams.map((team) => {
              const canLeaveTeam = !team.personal && team.role !== "owner"

              return (
                <div
                  key={team.id}
                  className="flex items-center justify-between gap-4 rounded-lg border p-4"
                >
                  <div className="flex items-center gap-4">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium">{team.name}</span>
                        {team.personal ? (
                          <Badge variant="secondary">Personal</Badge>
                        ) : null}
                      </div>
                      <span className="text-muted-foreground text-sm capitalize">
                        {team.role}
                      </span>
                    </div>
                  </div>

                  <TooltipProvider>
                    <div className="flex items-center gap-2">
                      {canLeaveTeam ? (
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button
                              variant="ghost"
                              size="sm"
                              aria-label="Leave team"
                              onClick={() => openLeaveTeamDialog(team)}
                            >
                              <LogOut className="h-4 w-4" />
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>
                            <p>Leave team</p>
                          </TooltipContent>
                        </Tooltip>
                      ) : null}

                      {team.role === "member" ? (
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button variant="ghost" size="sm" asChild>
                              <Link
                                href={settingsTeams.show(team.to_param)}
                                aria-label="View team"
                              >
                                <Eye className="h-4 w-4" />
                              </Link>
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>
                            <p>View team</p>
                          </TooltipContent>
                        </Tooltip>
                      ) : (
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <Button variant="ghost" size="sm" asChild>
                              <Link
                                href={settingsTeams.show(team.to_param)}
                                aria-label="Edit team"
                              >
                                <Pencil className="h-4 w-4" />
                              </Link>
                            </Button>
                          </TooltipTrigger>
                          <TooltipContent>
                            <p>Edit team</p>
                          </TooltipContent>
                        </Tooltip>
                      )}
                    </div>
                  </TooltipProvider>
                </div>
              )
            })}

            {teams.length === 0 ? (
              <p className="text-muted-foreground py-8 text-center">
                You don&apos;t belong to any teams yet.
              </p>
            ) : null}
          </div>
        </div>

        <LeaveTeamModal
          team={teamLeaving}
          open={leaveTeamDialogOpen}
          onOpenChange={setLeaveTeamDialogOpen}
        />
      </SettingsLayout>
    </AppLayout>
  )
}
