"use client";
import { toast as sonner } from "sonner";
import { isLocale, makeT, type Vars } from "@/lib/i18n/core";

/*
  Уведомления на языке кабинета: текст пишется по-русски (как ключ перевода), с подстановками {имя}.
  Язык берётся из <html lang>, который выставляет корневой макет и переключатель языка.
*/
function tr(message: string, vars?: Vars): string {
  const lang = typeof document !== "undefined" ? document.documentElement.lang : "ru";
  return makeT(isLocale(lang) ? lang : "ru")(message, vars);
}

export const toast = {
  success: (message: string, vars?: Vars) => sonner.success(tr(message, vars)),
  error: (message: string, vars?: Vars) => sonner.error(tr(message, vars)),
  info: (message: string, vars?: Vars) => sonner.info(tr(message, vars)),
};
