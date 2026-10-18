import { useState } from "react";
import { QRCodeSVG } from "qrcode.react";
import { useAppState } from "../context/AppStateContext";
import { useToast } from "../context/ToastContext";
import { useI18n } from "../i18n";
import { deviceUserId } from "../lib/deviceUser";
import { PageHeader } from "../components/PageHeader";
import { PrimaryButton } from "../components/PrimaryButton";

export function CheckInScreen() {
  const { t } = useI18n();
  const { recordActivity, streakDays } = useAppState();
  const { trigger } = useToast();
  const [isChecking, setIsChecking] = useState(false);

  async function checkIn() {
    setIsChecking(true);
    const leveledUp = await recordActivity();
    setIsChecking(false);
    trigger({
      icon: "✅",
      title: t("Checked in!"),
      subtitle: leveledUp ? `${streakDays + 1}${t("checkin.dayStreak")}` : t("Visit logged"),
      accent: "var(--good)",
    });
  }

  return (
    <div className="page">
      <PageHeader title={t("Check In")} />
      <div className="screen-padding stack" style={{ gap: 20, alignItems: "center", textAlign: "center", marginTop: 20 }}>
        <div style={{ background: "white", borderRadius: 20, padding: 20 }}>
          <QRCodeSVG value={`core-member:${deviceUserId}`} size={200} />
        </div>
        <span style={{ fontSize: 13, color: "var(--muted)" }}>{t("checkin.instructions")}</span>
        <div style={{ width: "100%" }}>
          <PrimaryButton color="purple" isLoading={isChecking} onClick={checkIn}>
            {t("checkin.cta")}
          </PrimaryButton>
        </div>
      </div>
    </div>
  );
}
