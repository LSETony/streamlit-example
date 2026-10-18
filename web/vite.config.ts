import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { VitePWA } from "vite-plugin-pwa";

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["fonts/*.ttf"],
      manifest: {
        name: "core. — fitness club",
        short_name: "core.",
        description: "Book sessions, track workouts, and manage your membership — no App Store required.",
        theme_color: "#1e1e1e",
        background_color: "#1e1e1e",
        display: "standalone",
        orientation: "portrait",
        start_url: "/",
        scope: "/",
        icons: [
          { src: "icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "icon-512.png", sizes: "512x512", type: "image/png" },
          { src: "maskable-icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,ttf,png,svg}"],
        // Supabase/API calls go straight to the network — never cache
        // booking/cart/member data, only the app shell itself.
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/ubykgrowhekmsvxhvjxf\.supabase\.co\/.*/,
            handler: "NetworkOnly",
          },
        ],
      },
    }),
  ],
});
