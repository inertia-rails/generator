import { createInertiaApp } from "@inertiajs/react"

import { initializeTheme } from "@/hooks/use-appearance"
import PersistentLayout from "@/layouts/persistent-layout"

const appName = import.meta.env.VITE_APP_NAME ?? "React Starter Kit"

void createInertiaApp({
  title: (title) => (title ? `${title} - ${appName}` : appName),
  strictMode: true,
  pages: "../pages",
  layout: () => PersistentLayout,
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({
      queryStringArrayFormat: "brackets",
    }),
  },
  progress: {
    color: "#4B5563",
  },
})

// This will set light / dark mode on load...
initializeTheme()
