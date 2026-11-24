import { dashboard, teamDashboard } from "@/routes"
import type { Team } from "@/types"

export function dashboardRoute(team: Team | null) {
  return team ? teamDashboard(team.to_param) : dashboard.index()
}
