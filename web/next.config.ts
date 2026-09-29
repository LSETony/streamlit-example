import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // самодостаточная сборка для Docker-образа (deploy/docker-compose.public.yml)
  output: "standalone",
  poweredByHeader: false,
};

export default nextConfig;
