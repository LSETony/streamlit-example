import { useEffect, useState } from "react";
import { useI18n } from "../i18n";

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
}

const DISMISSED_KEY = "core.web.installDismissed";

/// The whole point of this app, per the request that started it: no App
/// Store. `beforeinstallprompt` (Chrome/Edge/Android) lets this banner
/// trigger the native "Add to Home Screen" flow directly; Safari/iOS
/// doesn't fire that event at all — there, Add to Home Screen only lives
/// in the Share sheet, so the banner instead explains that explicitly.
export function InstallPrompt() {
  const { t } = useI18n();
  const [deferred, setDeferred] = useState<BeforeInstallPromptEvent | null>(null);
  const [dismissed, setDismissed] = useState(() => {
    try {
      return localStorage.getItem(DISMISSED_KEY) === "1";
    } catch {
      return false;
    }
  });
  const [isStandalone] = useState(
    () => window.matchMedia?.("(display-mode: standalone)").matches || (navigator as { standalone?: boolean }).standalone === true
  );

  useEffect(() => {
    function handler(e: Event) {
      e.preventDefault();
      setDeferred(e as BeforeInstallPromptEvent);
    }
    window.addEventListener("beforeinstallprompt", handler);
    return () => window.removeEventListener("beforeinstallprompt", handler);
  }, []);

  const isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);

  if (isStandalone || dismissed || (!deferred && !isIOS)) return null;

  function dismiss() {
    setDismissed(true);
    try {
      localStorage.setItem(DISMISSED_KEY, "1");
    } catch {
      /* ignore */
    }
  }

  async function install() {
    if (!deferred) return;
    await deferred.prompt();
    dismiss();
  }

  return (
    <div
      style={{
        position: "fixed",
        bottom: 0,
        left: 0,
        right: 0,
        zIndex: 200,
        background: "var(--surf2)",
        borderTop: "1px solid var(--line)",
        padding: "14px 20px calc(14px + env(safe-area-inset-bottom))",
        display: "flex",
        alignItems: "center",
        gap: 12,
      }}
    >
      <div className="stack" style={{ flex: 1 }}>
        <strong style={{ fontSize: 14 }}>{t("install.title")}</strong>
        <span style={{ fontSize: 12, color: "var(--muted)" }}>
          {deferred ? t("install.body") : isIOS ? "Tap Share, then “Add to Home Screen”." : t("install.body")}
        </span>
      </div>
      {deferred && (
        <button className="btn-primary" style={{ width: "auto", padding: "10px 16px", fontSize: 14 }} onClick={install}>
          {t("install.cta")}
        </button>
      )}
      <button onClick={dismiss} style={{ background: "none", border: "none", color: "var(--muted)", fontSize: 13, cursor: "pointer" }}>
        {t("install.dismiss")}
      </button>
    </div>
  );
}
