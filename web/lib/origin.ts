import "server-only";
import { headers } from "next/headers";

/** Публичный адрес кабинета: PUBLIC_APP_URL или адрес текущего запроса */
export async function appOrigin(): Promise<string> {
  if (process.env.PUBLIC_APP_URL) return process.env.PUBLIC_APP_URL.replace(/\/$/, "");
  const h = await headers();
  return `${h.get("x-forwarded-proto") ?? "https"}://${h.get("x-forwarded-host") ?? h.get("host")}`;
}
