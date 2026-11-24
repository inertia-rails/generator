import { Link<%= ", usePage" if use_teams %> } from "@inertiajs/react"
import { BookOpen, Folder, LayoutGrid } from "lucide-react"

import { NavFooter } from "@/components/nav-footer"
import { NavMain } from "@/components/nav-main"
import { NavUser } from "@/components/nav-user"
<% if use_teams %>
import { TeamSwitcher } from "@/components/team-switcher"
<% end %>
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar"
import { <%= use_teams ? "teamDashboard" : "dashboard" %> } from "@/routes"
import type { NavItem } from "@/types"

import AppLogo from "./app-logo"

<% unless use_teams %>
const mainNavItems: NavItem[] = [
  {
    title: "Dashboard",
    href: dashboard.index().url,
    icon: LayoutGrid,
  },
]

<% end %>
const footerNavItems: NavItem[] = [
  {
    title: "Repository",
    href: "https://github.com/inertia-rails/react-starter-kit",
    icon: Folder,
  },
  {
    title: "Documentation",
    href: "https://inertia-rails.dev",
    icon: BookOpen,
  },
]

export function AppSidebar() {
<% if use_teams %>
  const { current_team } = usePage().props

  const mainNavItems: NavItem[] = [
    {
      title: "Dashboard",
      href: teamDashboard(current_team.to_param).url,
      icon: LayoutGrid,
    },
  ]

<% end %>
  return (
    <Sidebar collapsible="icon" variant="inset">
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <Link
                href={<%= use_teams ? "teamDashboard(current_team.to_param)" : "dashboard.index()" %>}
<% unless use_teams %>
                prefetch
<% end %>
              >
                <AppLogo />
              </Link>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
<% if use_teams %>
        <SidebarMenu>
          <SidebarMenuItem>
            <TeamSwitcher />
          </SidebarMenuItem>
        </SidebarMenu>
<% end %>
      </SidebarHeader>

      <SidebarContent>
        <NavMain items={mainNavItems} />
      </SidebarContent>

      <SidebarFooter>
        <NavFooter items={footerNavItems} className="mt-auto" />
        <NavUser />
      </SidebarFooter>
    </Sidebar>
  )
}
