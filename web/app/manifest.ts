import type { MetadataRoute } from "next";

/** Установка на экран «Домой»: открывается без адресной строки, как приложение */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "core. — кабинет зала",
    short_name: "core.",
    description: "Клиенты, абонементы, посещения, расписание и клиенты в зоне риска",
    start_url: "/",
    display: "standalone",
    background_color: "#510bf5",
    theme_color: "#f2f2f7",
    lang: "ru",
    icons: [
      { src: "/brand/app-192.png", sizes: "192x192", type: "image/png" },
      { src: "/brand/app-512.png", sizes: "512x512", type: "image/png" },
      { src: "/brand/app-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
