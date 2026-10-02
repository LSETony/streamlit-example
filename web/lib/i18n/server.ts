import "server-only";
import { cache } from "react";
import { cookies, headers } from "next/headers";
import { isLocale, localeFromAcceptLanguage, LOCALE_COOKIE, makeT, type Locale } from "./core";

/** Язык запроса: выбор пользователя (cookie), иначе язык браузера */
export const getLocale = cache(async (): Promise<Locale> => {
  const saved = (await cookies()).get(LOCALE_COOKIE)?.value;
  if (isLocale(saved)) return saved;
  return localeFromAcceptLanguage((await headers()).get("accept-language"));
});

export async function getT() {
  return makeT(await getLocale());
}
