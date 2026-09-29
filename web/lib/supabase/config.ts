// Адреса Supabase. Браузер ходит по публичному адресу API, сервер кабинета — по внутреннему
// (SUPABASE_INTERNAL_URL, например http://kong:8000 в docker-compose), чтобы не зависеть от «петли» через интернет.
// Имя cookie сессии фиксировано: иначе оно зависело бы от адреса и сервер не видел бы сессию браузера.
export const PUBLIC_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
export const ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
export const SESSION_COOKIE = "sb-core-auth-token";

export function serverUrl(): string {
  return process.env.SUPABASE_INTERNAL_URL || PUBLIC_URL;
}
