import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // самодостаточная сборка для Docker-образа (deploy/docker-compose.public.yml)
  output: "standalone",
  poweredByHeader: false,
  // кабинет нельзя встроить в чужой сайт (защита от кликджекинга); встраивается только виджет записи /w/…
  async headers() {
    return [
      { source: "/((?!w/).*)", headers: [{ key: "X-Frame-Options", value: "DENY" }, { key: "Content-Security-Policy", value: "frame-ancestors 'none'" }] },
      { source: "/w/:path*", headers: [{ key: "Content-Security-Policy", value: "frame-ancestors *" }] },
    ];
  },
};

export default nextConfig;
