import { useCallback, useMemo, useState, type ReactNode } from "react";
import { I18nContext, LANGUAGE_STORAGE_KEY, translate, type Language } from "./index";

function readStoredLanguage(): Language {
  try {
    const stored = localStorage.getItem(LANGUAGE_STORAGE_KEY);
    if (stored === "en" || stored === "ru") return stored;
  } catch {
    // localStorage can throw in private browsing / blocked storage — fall through.
  }
  const nav = typeof navigator !== "undefined" ? navigator.language : "en";
  return nav.toLowerCase().startsWith("ru") ? "ru" : "en";
}

/// Mirrors AppState.preferredLanguage from the iOS app: persists the
/// choice, and — same reasoning as Font.uiFontFamilyOverride there —
/// swaps the whole document's font-family via a CSS class on <html> so
/// every element restyles to Geologica at once, not just headings.
export function I18nProvider({ children }: { children: ReactNode }) {
  const [language, setLanguageState] = useState<Language>(readStoredLanguage);

  const setLanguage = useCallback((next: Language) => {
    setLanguageState(next);
    try {
      localStorage.setItem(LANGUAGE_STORAGE_KEY, next);
    } catch {
      // Ignore — worst case the choice doesn't survive a reload.
    }
    document.documentElement.lang = next;
    document.documentElement.classList.toggle("lang-ru", next === "ru");
  }, []);

  useMemo(() => {
    document.documentElement.lang = language;
    document.documentElement.classList.toggle("lang-ru", language === "ru");
  }, [language]);

  const t = useCallback((key: string) => translate(language, key), [language]);

  const value = useMemo(() => ({ language, setLanguage, t }), [language, setLanguage, t]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}
