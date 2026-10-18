import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Globe } from "lucide-react";
import { useAuth } from "../context/AuthContext";
import { useI18n } from "../i18n";
import { PrimaryButton } from "../components/PrimaryButton";
import { LanguagePickerScreen } from "./LanguagePickerScreen";

export function AuthWelcomeScreen() {
  const { t } = useI18n();
  const { startEmailRegistration, isBusy, error, clearError } = useAuth();
  const navigate = useNavigate();
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [showLanguage, setShowLanguage] = useState(false);

  const canContinue = fullName.trim().length > 0 && /\S+@\S+\.\S+/.test(email);

  async function handleContinue() {
    if (!canContinue) return;
    const ok = await startEmailRegistration(email);
    if (ok) navigate(`/otp?name=${encodeURIComponent(fullName)}&email=${encodeURIComponent(email)}`);
  }

  return (
    <div className="page auth-bg">
      <div className="row screen-padding" style={{ paddingTop: "calc(16px + env(safe-area-inset-top))", justifyContent: "flex-end" }}>
        <button
          onClick={() => setShowLanguage(true)}
          aria-label="Language"
          style={{ background: "rgba(255,255,255,0.12)", border: "none", borderRadius: "50%", width: 40, height: 40, color: "white", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
        >
          <Globe size={18} />
        </button>
      </div>

      <div className="screen-padding stack" style={{ gap: 24, marginTop: 40 }}>
        <div className="stack" style={{ gap: 8 }}>
          <span className="brand" style={{ fontSize: 15, color: "var(--accent-purple)", letterSpacing: 2, textTransform: "uppercase" }}>
            core.
          </span>
          <h1 className="brand" style={{ fontSize: 36, margin: 0 }}>{t("Member")}</h1>
        </div>

        <div className="stack" style={{ gap: 10 }}>
          <input
            type="text"
            placeholder={t("auth.fullName")}
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
          />
          <input
            type="email"
            placeholder={t("auth.email")}
            value={email}
            onChange={(e) => {
              setEmail(e.target.value);
              clearError();
            }}
          />
        </div>

        {error && <div style={{ color: "var(--warn)", fontSize: 13 }}>{error}</div>}

        <PrimaryButton color="purple" disabled={!canContinue} isLoading={isBusy} onClick={handleContinue}>
          {t("auth.continueWithEmail")}
        </PrimaryButton>

        <div className="stack" style={{ gap: 10, opacity: 0.5 }}>
          <div className="divider" />
          <span style={{ fontSize: 12, color: "var(--muted)" }}>{t("auth.appleUnavailable")}</span>
          <span style={{ fontSize: 12, color: "var(--muted)" }}>{t("auth.googleUnavailable")}</span>
        </div>
      </div>

      {showLanguage && <LanguagePickerScreen onClose={() => setShowLanguage(false)} asSheet />}
    </div>
  );
}
