<script setup lang="ts">
import { Link<%= ", usePage" if use_teams %> } from "@inertiajs/vue3"
import { BookOpen, Folder, LayoutGrid } from "lucide-vue-next"
<% if use_teams %>
import { computed } from "vue"
<% end %>

import NavFooter from "@/components/NavFooter.vue"
import NavMain from "@/components/NavMain.vue"
import NavUser from "@/components/NavUser.vue"
<% if use_teams %>
import TeamSwitcher from "@/components/TeamSwitcher.vue"
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
import { type NavItem } from "@/types"

import AppLogo from "./AppLogo.vue"

<% if use_teams %>
const page = usePage()
const dashboardUrl = computed(
  () => teamDashboard(page.props.current_team.slug).url,
)

const mainNavItems = computed<NavItem[]>(() => [
  {
    title: "Dashboard",
    href: dashboardUrl.value,
    icon: LayoutGrid,
  },
])
<% else %>
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
    title: "Github Repo",
    href: "https://github.com/inertia-rails/vue-starter-kit",
    icon: Folder,
  },
  {
    title: "Documentation",
    href: "https://inertia-rails.dev",
    icon: BookOpen,
  },
]
</script>

<template>
  <Sidebar collapsible="icon" variant="inset">
    <SidebarHeader>
      <SidebarMenu>
        <SidebarMenuItem>
          <SidebarMenuButton size="lg" as-child>
            <Link :href="<%= use_teams ? "dashboardUrl" : "dashboard.index()" %>">
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
      <NavMain :items="mainNavItems" />
    </SidebarContent>

    <SidebarFooter>
      <NavFooter :items="footerNavItems" />
      <NavUser />
    </SidebarFooter>
  </Sidebar>
  <slot />
</template>
