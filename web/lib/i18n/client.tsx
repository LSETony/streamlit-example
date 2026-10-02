"use client";
import { createContext, useContext, useMemo } from "react";
import { makeT, type Locale, type T } from "./core";

const I18nContext = createContext<T>(makeT("ru"));

export function I18nProvider({ locale, children }: { locale: Locale; children: React.ReactNode }) {
  const t = useMemo(() => makeT(locale), [locale]);
  return <I18nContext.Provider value={t}>{children}</I18nContext.Provider>;
}

export function useT(): T {
  return useContext(I18nContext);
}
