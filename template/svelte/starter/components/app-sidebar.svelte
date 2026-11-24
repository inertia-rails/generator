<script lang="ts">
  import { Link<%= ", page" if use_teams %> } from "@inertiajs/svelte"
  import { BookOpen, Folder, LayoutGrid } from "@lucide/svelte"

  import NavFooter from "@/components/nav-footer.svelte"
  import NavMain from "@/components/nav-main.svelte"
  import NavUser from "@/components/nav-user.svelte"
<% if use_teams %>
  import TeamSwitcher from "@/components/team-switcher.svelte"
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
<% if use_teams %>
  import { dashboardRoute } from "@/lib/dashboard-route"
<% else %>
  import { dashboard } from "@/routes"
<% end %>
  import { type NavItem } from "@/types"

  import AppLogo from "./app-logo.svelte"

<% if use_teams %>
  const dashboardUrl = $derived(dashboardRoute(page.props.current_team).url)

  const mainNavItems = $derived<NavItem[]>([
    {
      title: "Dashboard",
      href: dashboardUrl,
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
      href: "https://github.com/inertia-rails/svelte-starter-kit",
      icon: Folder,
    },
    {
      title: "Documentation",
      href: "https://inertia-rails.dev",
      icon: BookOpen,
    },
  ]
</script>

<Sidebar collapsible="icon" variant="inset">
  <SidebarHeader>
    <SidebarMenu>
      <SidebarMenuItem>
        <SidebarMenuButton size="lg">
          {#snippet child({ props })}
            <Link {...props} href={<%= use_teams ? "dashboardUrl" : "dashboard.index()" %>}>
              <AppLogo />
            </Link>
          {/snippet}
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
    <NavFooter items={footerNavItems} />
    <NavUser />
  </SidebarFooter>
</Sidebar>
