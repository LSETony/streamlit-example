import { useState } from "react";
import { useAppState } from "../context/AppStateContext";
import { useI18n } from "../i18n";
import { PageHeader } from "../components/PageHeader";
import { PrimaryButton } from "../components/PrimaryButton";

export function ReferralScreen() {
  const { t } = useI18n();
  const { referralCode, redeemReferralCode } = useAppState();
  const [input, setInput] = useState("");
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(referralCode);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      /* ignore */
    }
  }

  return (
    <div className="page">
      <PageHeader title={t("Invite a friend")} />
      <div className="screen-padding stack" style={{ gap: 24 }}>
        <div className="card stack" style={{ gap: 12, alignItems: "center", textAlign: "center" }}>
          <span style={{ fontSize: 13, color: "var(--muted)" }}>{t("Your referral code")}</span>
          <span className="digital" style={{ fontSize: 28, letterSpacing: 2 }}>{referralCode || "…"}</span>
          <button onClick={copy} className="btn-primary purple" style={{ width: "auto", padding: "10px 20px", fontSize: 14 }}>
            {copied ? t("referral.copied") : t("referral.copyCode")}
          </button>
        </div>

        <div className="stack" style={{ gap: 10 }}>
          <span style={{ fontSize: 14, fontWeight: 600 }}>{t("I was invited")}</span>
          <input type="text" placeholder={t("referral.enterCode")} value={input} onChange={(e) => setInput(e.target.value)} />
          <PrimaryButton
            disabled={input.trim().length === 0}
            onClick={() => {
              redeemReferralCode(input);
              setInput("");
            }}
          >
            {t("referral.redeem")}
          </PrimaryButton>
        </div>
      </div>
    </div>
  );
}
