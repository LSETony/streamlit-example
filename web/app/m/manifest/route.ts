import { getT } from "@/lib/i18n/server";

// Отдельная установка на экран «Домой» для клиентов зала: открывается сразу на пропуске
export async function GET() {
  const t = await getT();
  return Response.json({
    name: t("core. — мой зал"),
    short_name: "core.",
    description: t("Пропуск в зал, абонементы и запись на занятия"),
    start_url: "/m",
    scope: "/m",
    display: "standalone",
    background_color: "#510bf5",
    theme_color: "#510bf5",
    icons: [
      { src: "/brand/app-192.png", sizes: "192x192", type: "image/png" },
      { src: "/brand/app-512.png", sizes: "512x512", type: "image/png" },
      { src: "/brand/app-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  }, { headers: { "Content-Type": "application/manifest+json" } });
}
