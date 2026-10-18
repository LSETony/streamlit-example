import { useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useI18n } from "../i18n";
import { PrimaryButton } from "../components/PrimaryButton";
import { EyebrowLabel } from "../components/EyebrowLabel";

const CODE_LENGTH = 8;

export function OTPVerificationScreen() {
  const { t } = useI18n();
  const { verifyEmailCode, startEmailRegistration, isBusy, error, clearError } = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const name = params.get("name") ?? "";
  const email = params.get("email") ?? "";
  const [code, setCode] = useState("");
  const [secondsRemaining, setSecondsRemaining] = useState(48);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  useEffect(() => {
    if (secondsRemaining <= 0) return;
    const id = setInterval(() => setSecondsRemaining((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(id);
  }, [secondsRemaining]);

  if (!email) {
    navigate("/");
    return null;
  }

  async function verify() {
    const ok = await verifyEmailCode(name, email, code);
    if (ok) navigate("/");
  }

  async function resend() {
    setSecondsRemaining(48);
    await startEmailRegistration(email);
  }

  return (
    <div className="page auth-bg">
      <div className="screen-padding stack" style={{ gap: 28, marginTop: "calc(60px + env(safe-area-inset-top))" }}>
        <div className="stack" style={{ gap: 10, textAlign: "center", alignItems: "center" }}>
          <EyebrowLabel color="var(--accent-purple)">{t("One-Time Code")}</EyebrowLabel>
          <h1 className="brand" style={{ fontSize: 34, margin: 0 }}>{t("Authorization")}</h1>
          <span style={{ fontSize: 15, color: "rgba(255,255,255,0.85)" }}>
            {t("otp.enterCodeSentTo")} {email}
          </span>
        </div>

        <input
          ref={inputRef}
          type="text"
          inputMode="numeric"
          autoComplete="one-time-code"
          value={code}
          maxLength={CODE_LENGTH}
          onChange={(e) => {
            setCode(e.target.value.replace(/\D/g, "").slice(0, CODE_LENGTH));
            clearError();
          }}
          style={{ textAlign: "center", fontSize: 22, letterSpacing: 10, fontFamily: "var(--font-digital)" }}
          placeholder={"•".repeat(CODE_LENGTH)}
        />

        <div className="row" style={{ justifyContent: "center", gap: 4, fontSize: 14 }}>
          <span style={{ color: "var(--muted)" }}>{t("Didn't get a code?")}</span>
          {secondsRemaining > 0 ? (
            <span style={{ color: "var(--accent)", fontWeight: 600 }}>
              {t("otp.resendIn")} {String(Math.floor(secondsRemaining / 60)).padStart(2, "0")}:{String(secondsRemaining % 60).padStart(2, "0")}
            </span>
          ) : (
            <button onClick={resend} style={{ background: "none", border: "none", color: "var(--accent)", fontWeight: 600, cursor: "pointer" }}>
              {t("Resend")}
            </button>
          )}
        </div>

        {error && <div style={{ color: "var(--warn)", fontSize: 13, textAlign: "center" }}>{error}</div>}

        <PrimaryButton color="purple" disabled={code.length !== CODE_LENGTH} isLoading={isBusy} onClick={verify}>
          {t("Continue")}
        </PrimaryButton>
      </div>
    </div>
  );
}
